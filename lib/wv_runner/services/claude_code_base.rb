# frozen_string_literal: true

require 'open3'
require 'json'
require 'shellwords'
require 'timeout'
require_relative 'output_formatter'

module WvRunner
  # Raised when IO stream unexpectedly closes during Claude execution
  class StreamClosedError < StandardError; end

  # Raised when WVRUNNER_RESULT marker is not found in output
  class MissingMarkerError < StandardError; end

  # Base class for Claude Code executors
  # Handles common execution, streaming, and JSON parsing logic
  # Subclasses must implement:
  # - build_instructions() -> returns instruction string
  # - model_name() -> returns the model to use (e.g., 'sonnet', 'haiku', 'opus')
  class ClaudeCodeBase
    CLAUDE_EXECUTION_TIMEOUT = 3600 # 1 hour in seconds
    SOFT_TIMEOUT = 3300 # 55 minutes — send SIGTERM to let Claude flush output before hard kill
    MAX_RETRY_ATTEMPTS = 3
    RETRY_WAIT_SECONDS = 30
    PROCESS_KILL_TIMEOUT = 5 # seconds to wait for SIGTERM before SIGKILL

    def initialize(verbose: false)
      @verbose = verbose
      @stopping = false
      @retry_count = 0
      @marker_retry_mode = false
      @result_received = false
      @child_pid = nil
      @soft_timeout_fired = false
      @execution_start_time = nil
      OutputFormatter.verbose_mode = verbose
    end

    def run
      Logger.info_stdout "[#{self.class.name}] Starting execution..."
      Logger.info_stdout "[#{self.class.name}] Output mode: #{@verbose ? 'VERBOSE' : 'NORMAL'}"
      start_time = Time.now
      @accumulated_output = ''.dup

      run_with_retry(start_time)
    end

    private

    def run_with_retry(start_time)
      loop do
        result = attempt_execution(start_time)
        return result if result

        @retry_count += 1
        break if @retry_count >= MAX_RETRY_ATTEMPTS

        Logger.info_stdout "[#{self.class.name}] Waiting #{RETRY_WAIT_SECONDS}s before retry #{@retry_count}/#{MAX_RETRY_ATTEMPTS}..."
        sleep(RETRY_WAIT_SECONDS)
      end

      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)
      error_result("Claude execution failed after #{MAX_RETRY_ATTEMPTS} retry attempts (#{elapsed_hours} hours)")
    end

    def attempt_execution(start_time)
      claude_path = resolve_claude_path
      instructions = @marker_retry_mode ? build_marker_retry_instructions : build_instructions
      command = build_command(claude_path, instructions, continue_session: @retry_count.positive? || @marker_retry_mode)

      Logger.debug "[#{self.class.name}] Executing Claude with instructions (length: #{instructions.length} chars)"
      Logger.info_stdout "[#{self.class.name}] Starting real-time stream of Claude output:"
      Logger.info_stdout "[#{self.class.name}] Retry attempt: #{@retry_count + 1}/#{MAX_RETRY_ATTEMPTS}" if @retry_count.positive?
      Logger.info_stdout "[#{self.class.name}] Marker retry mode: ON" if @marker_retry_mode
      Logger.info_stdout '-' * 80

      @stopping = false
      stdout_content = execute_with_streaming(command)
      @accumulated_output << stdout_content

      Logger.info_stdout "[#{self.class.name}] Soft timeout fired but execution completed" if @soft_timeout_fired
      Logger.info_stdout '-' * 80
      Logger.info_stdout "[#{self.class.name}] Claude execution completed, parsing results..."

      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)
      Logger.info_stdout "[#{self.class.name}] Elapsed time: #{elapsed_hours} hours"

      result = parse_result(@accumulated_output, elapsed_hours)

      # If marker not found and Claude completed successfully, retry with marker-only instruction
      if result['status'] == 'error' && result['message'].include?('WVRUNNER_RESULT')
        raise MissingMarkerError
      end

      result
    rescue Timeout::Error
      handle_recoverable_error('Timeout', start_time)
    rescue StreamClosedError => e
      handle_recoverable_error("Stream closed: #{e.message}", start_time)
    rescue MissingMarkerError
      handle_marker_retry(start_time)
    end

    def handle_recoverable_error(error_type, start_time)
      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)

      if @retry_count >= MAX_RETRY_ATTEMPTS - 1
        Logger.error "[#{self.class.name}] #{error_type} - max retries reached"
        return error_result("#{error_type} after #{CLAUDE_EXECUTION_TIMEOUT}s (#{elapsed_hours}h), retries exhausted")
      end

      Logger.warn "[#{self.class.name}] #{error_type} after #{elapsed_hours}h - will retry with --continue"
      nil # Signal to retry
    end

    def handle_marker_retry(start_time)
      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)

      if @retry_count >= MAX_RETRY_ATTEMPTS - 1
        Logger.error "[#{self.class.name}] Missing marker - max retries reached"
        return error_result("Missing WVRUNNER_RESULT after retries exhausted (#{elapsed_hours}h)")
      end

      Logger.warn "[#{self.class.name}] Missing WVRUNNER_RESULT marker - will retry with marker-only instruction"
      @marker_retry_mode = true
      nil # Signal to retry
    end

    def build_marker_retry_instructions
      original_instructions = build_instructions

      <<~INSTRUCTIONS
        Your previous session was interrupted before completing the workflow.

        Please:
        1. Check what you already completed (git status, git log, check for open PRs)
        2. Continue from where you left off in the workflow below
        3. Complete ALL remaining steps
        4. At the END, output the WVRUNNER_RESULT marker as specified

        IMPORTANT: Do NOT just output the marker - first verify and complete any remaining work!

        === ORIGINAL WORKFLOW (continue from where you left off) ===

        #{original_instructions}
      INSTRUCTIONS
    end

    def resolve_claude_path
      Logger.debug "[#{self.class.name}] Resolving Claude executable path..."
      claude_path = ENV['CLAUDE_PATH'] || find_claude_executable
      raise 'Claude executable not found. Set CLAUDE_PATH environment variable.' unless claude_path

      Logger.info_stdout "[#{self.class.name}] Found Claude at: #{claude_path}"
      claude_path
    end

    def build_command(claude_path, instructions, continue_session: false)
      cmd = [claude_path]
      cmd << '--continue' if continue_session
      cmd.concat(['-p', instructions, '--model', model_name, '--output-format=stream-json', '--verbose'])
      cmd << '--permission-mode=acceptEdits' if accept_edits?
      Logger.debug "command: #{cmd.map { |arg| Shellwords.escape(arg) }.join(' ')}"
      cmd
    end

    def accept_edits?
      true # Override in subclass if needed
    end

    def execute_with_streaming(command)
      stdout_content = ''.dup
      stderr_content = ''.dup
      stream_error = nil
      @result_received = false
      @child_pid = nil
      @execution_start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @soft_timeout_fired = false

      Timeout.timeout(CLAUDE_EXECUTION_TIMEOUT) do
        Open3.popen3(*command) do |stdin, stdout, stderr, wait_thr|
          @child_pid = wait_thr.pid
          stdin.close

          soft_timeout_thread = Thread.new do
            remaining = SOFT_TIMEOUT - elapsed_execution_seconds
            sleep(remaining) if remaining > 0
            unless @stopping || @result_received
              @soft_timeout_fired = true
              Process.kill('TERM', wait_thr.pid) rescue Errno::ESRCH
              release_test_lock
            end
          end

          stdout_thread = Thread.new do
            stream_lines(stdout) do |line|
              stdout_content << line.dup
              check_for_result_message(line)
              if OutputFormatter.should_log_to_stdout?(line)
                formatted = OutputFormatter.format_line(line)
                puts formatted
                Logger.info(formatted)
              else
                Logger.debug("[#{self.class.name}] [streaming] #{line.strip}")
              end
            end
          rescue IOError, Errno::EBADF => e
            handle_stream_error(e, 'stdout') { |err| stream_error = err }
          end

          stderr_thread = Thread.new do
            stream_lines(stderr) do |line|
              Logger.warn "\n[Claude STDERR] #{line}"
              stderr_content << line.dup
            end
          rescue IOError, Errno::EBADF => e
            handle_stream_error(e, 'stderr') { |err| stream_error ||= err }
          end

          begin
            stdout_thread.join
            stderr_thread.join

            # Check if stream was unexpectedly closed
            raise StreamClosedError, stream_error if stream_error && !@stopping

            exit_status = wait_thr.value
            Logger.debug "[#{self.class.name}] Process exit status: #{exit_status.exitstatus}"

            if exit_status.exitstatus != 0
              Logger.debug "[#{self.class.name}] WARNING: Claude exited with non-zero status!"
              Logger.debug "[#{self.class.name}] stderr: #{stderr_content}" unless stderr_content.empty?
            end
          ensure
            soft_timeout_thread&.kill
            kill_process(wait_thr.pid)
          end
        end
      end

      stdout_content
    rescue Timeout::Error
      @stopping = true
      Logger.error "[#{self.class.name}] Claude execution timed out after #{CLAUDE_EXECUTION_TIMEOUT} seconds"
      kill_process(@child_pid) if @child_pid
      release_test_lock
      raise
    end

    def kill_process(pid)
      return unless pid

      Logger.info_stdout "[#{self.class.name}] Terminating Claude process (pid: #{pid})..."
      begin
        Process.kill('TERM', pid)
      rescue Errno::ESRCH
        return # Already dead
      end

      PROCESS_KILL_TIMEOUT.times do
        sleep(1)
        begin
          Process.kill(0, pid)
        rescue Errno::ESRCH
          Logger.debug "[#{self.class.name}] Process #{pid} terminated after SIGTERM"
          return
        end
      end

      Logger.warn "[#{self.class.name}] Process #{pid} not responding to SIGTERM, sending SIGKILL..."
      begin
        Process.kill('KILL', pid)
      rescue Errno::ESRCH
        # Already dead
      end
    rescue StandardError => e
      Logger.warn "[#{self.class.name}] Error during process cleanup: #{e.message}"
    end

    def stream_lines(io)
      io.each_line do |line|
        yield line
        break if @result_received
      end
    end

    def handle_stream_error(error, stream_name)
      return if @stopping # Expected closure during timeout/shutdown

      error_msg = "#{stream_name} stream closed unexpectedly: #{error.message}"
      Logger.warn "[#{self.class.name}] #{error_msg}"
      yield error_msg
    end

    def check_for_result_message(line)
      return if @result_received

      parsed = JSON.parse(line)
      return unless parsed['type'] == 'result'

      @result_received = true
      @stopping = true # Mark as expected shutdown
      Logger.info_stdout "[#{self.class.name}] Result received, stopping streams..."
    rescue JSON::ParserError
      # Not JSON or invalid, ignore
    end

    def build_instructions
      raise NotImplementedError, "#{self.class} must implement build_instructions"
    end

    def model_name
      raise NotImplementedError, "#{self.class} must implement model_name"
    end

    def parse_result(stdout, elapsed_hours)
      Logger.debug "[#{self.class.name}] [parse_result] Starting to parse Claude output..."
      Logger.debug "[#{self.class.name}] [parse_result] Total output length: #{stdout.length} chars"

      marker = 'WVRUNNER_RESULT: '
      Logger.debug "[#{self.class.name}] [parse_result] Searching for marker: '#{marker}'"

      index = stdout.index(marker)
      unless index
        Logger.debug "[#{self.class.name}] [parse_result] ERROR: Marker not found in output!"
        Logger.debug "[#{self.class.name}] [parse_result] First 500 chars: #{stdout.first(500)}"
        Logger.debug "[#{self.class.name}] [parse_result] Last 500 chars: #{stdout.last(500)}"
        # Check if there are any code blocks that might contain partial marker
        code_blocks = stdout.scan(/```[\s\S]{0,100}/).first(3)
        Logger.debug "[#{self.class.name}] [parse_result] Code block starts found: #{code_blocks.inspect}" if code_blocks.any?
        return error_result('No WVRUNNER_RESULT found in output')
      end

      Logger.debug "[#{self.class.name}] [parse_result] Marker found at index #{index}"

      after_marker = stdout[(index + marker.length)..]
      Logger.debug "[#{self.class.name}] [parse_result] Content after marker (first 300 chars): #{after_marker[0...300]}"

      brace_index = after_marker.index('{')
      unless brace_index
        Logger.debug "[#{self.class.name}] [parse_result] ERROR: No opening brace found after marker!"
        return error_result('Could not find JSON object after WVRUNNER_RESULT marker')
      end

      Logger.debug "[#{self.class.name}] [parse_result] Opening brace found at index #{brace_index}"

      json_str = after_marker[brace_index..]
      Logger.debug "[#{self.class.name}] [parse_result] Extracted JSON string (first 200 chars): #{json_str[0...200]}"

      json_end = find_json_end(json_str)
      unless json_end
        Logger.debug "[#{self.class.name}] [parse_result] ERROR: Could not find JSON object boundaries!"
        Logger.debug "[#{self.class.name}] [parse_result] JSON string: #{json_str[0...300]}"
        return error_result('Could not find complete JSON object')
      end

      Logger.debug "[#{self.class.name}] [parse_result] JSON object ends at position #{json_end}"

      json_content = json_str[0...json_end].strip
      json_content = json_content.gsub('\"', '"')
      json_content = json_content.gsub('\\\"', '\"')
      Logger.debug "[#{self.class.name}] [parse_result] Final JSON content to parse: #{json_content}"

      begin
        result = JSON.parse(json_content).tap { |obj| obj['hours']['task_worked'] = elapsed_hours }
        Logger.debug "[#{self.class.name}] [parse_result] Successfully parsed result: #{result.inspect}"
        log_task_info(result)
        result
      rescue JSON::ParserError => e
        Logger.debug "[#{self.class.name}] [parse_result] ERROR: JSON parsing failed: #{e.message}"
        Logger.debug "[#{self.class.name}] [parse_result] Attempted to parse: #{json_content.inspect}"
        error_result("Failed to parse JSON: #{e.message}")
      end
    end

    def log_task_info(result)
      if result['task_info']
        Logger.debug '[parse_result] DEBUG: Extracted task_info:'
        Logger.debug "  - name: #{result['task_info']['name']}"
        Logger.debug "  - id: #{result['task_info']['id']}"
        Logger.debug "  - status: #{result['task_info']['status']}"
      end
      return unless result['hours']

      Logger.debug '[parse_result] DEBUG: Extracted hours:'
      Logger.debug "  - per_day: #{result['hours']['per_day']}"
      Logger.debug "  - task_estimated: #{result['hours']['task_estimated']}"
      Logger.debug "  - task_worked: #{result['hours']['task_worked']}"
    end

    def find_json_end(json_str)
      brace_count = 0
      i = 0

      while i < json_str.length
        char = json_str[i]

        if char == '\\'
          backslash_count = 0
          j = i
          while j < json_str.length && json_str[j] == '\\'
            backslash_count += 1
            j += 1
          end

          if j < json_str.length && json_str[j] == '"' && backslash_count.odd?
            i = j + 1
            next
          end
        end

        if char == '{'
          brace_count += 1
        elsif char == '}'
          brace_count -= 1
          return i + 1 if brace_count.zero?
        end

        i += 1
      end

      Logger.debug "[#{self.class.name}] [find_json_end] ERROR: JSON object not properly closed, final brace_count: #{brace_count}"
      nil
    end

    def error_result(message)
      Logger.debug "[#{self.class.name}] [error_result] Creating error result: #{message}"
      { 'status' => 'error', 'message' => message }
    end

    def elapsed_execution_seconds
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - @execution_start_time
    end

    def time_awareness_instruction
      <<~INSTRUCTION.strip
        TIME MANAGEMENT (CRITICAL):
        - You have a HARD 55-MINUTE execution limit. After 55 minutes you will be terminated.
        - Before starting any long-running step (system tests, full CI), consider elapsed time.
        - If more than 40 minutes have elapsed, SKIP full test suites and full CI.
          Instead: run only targeted tests for YOUR changes, then proceed to output WVRUNNER_RESULT.
        - ALWAYS prioritize outputting WVRUNNER_RESULT before the time limit.
      INSTRUCTION
    end

    def release_test_lock
      test_lock = File.expand_path('~/.claude/bin/test_lock')
      return unless File.executable?(test_lock)

      system(test_lock, 'release')
    rescue StandardError => e
      Logger.warn "[#{self.class.name}] Failed to release test lock: #{e.message}"
    end

    def find_claude_executable
      Logger.debug "[#{self.class.name}] [find_claude_executable] Searching for Claude executable..."
      paths = %w[~/.claude/local/claude ~/.local/bin/claude /usr/local/bin/claude /opt/homebrew/bin/claude]

      paths.each do |path|
        expanded_path = File.expand_path(path)
        Logger.debug "[#{self.class.name}] [find_claude_executable] Checking: #{expanded_path}"
        if File.executable?(expanded_path)
          Logger.debug "[#{self.class.name}] [find_claude_executable] Found executable Claude at: #{expanded_path}"
          return expanded_path
        else
          Logger.debug "[#{self.class.name}] [find_claude_executable] Not found or not executable: #{expanded_path}"
        end
      end

      Logger.debug "[#{self.class.name}] [find_claude_executable] Trying 'which claude' fallback..."
      which_path = find_claude_via_which
      if which_path
        Logger.debug "[#{self.class.name}] [find_claude_executable] Found executable Claude via 'which': #{which_path}"
        return which_path
      end

      Logger.debug "[#{self.class.name}] [find_claude_executable] ERROR: Claude executable not found in any standard locations"
      nil
    end

    def find_claude_via_which
      output = IO.popen(['which', 'claude'], &:read).strip
      return output if output && !output.empty? && File.executable?(output)

      nil
    rescue StandardError => e
      Logger.debug "[#{self.class.name}] [find_claude_via_which] Error running 'which claude': #{e.message}"
      nil
    end

    def project_relative_id
      return nil unless File.exist?('CLAUDE.md')

      File.read('CLAUDE.md').match(/project_relative_id=(\d+)/)&.then { |m| m[1].to_i }
    end
  end
end
