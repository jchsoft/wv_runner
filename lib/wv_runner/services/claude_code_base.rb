# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'json'
require 'shellwords'
require 'timeout'
require_relative 'output_formatter'
require_relative 'concerns/process_management'
require_relative 'concerns/retry_handling'
require_relative 'concerns/stream_processing'
require_relative 'concerns/result_parsing'
require_relative 'concerns/instruction_building'

module WvRunner
  # Raised when IO stream unexpectedly closes during Claude execution
  class StreamClosedError < StandardError; end

  # Raised when WVRUNNER_RESULT marker is not found in output
  class MissingMarkerError < StandardError; end

  # Raised when Claude exits due to API overload (529 errors)
  class ApiOverloadError < StandardError; end

  # Base class for Claude Code executors
  # Handles common execution, streaming, and JSON parsing logic
  # Subclasses must implement:
  # - build_instructions() -> returns instruction string
  # - model_name() -> returns the model to use (e.g., 'sonnet', 'haiku', 'opus')
  class ClaudeCodeBase
    include Concerns::ProcessManagement
    include Concerns::RetryHandling
    include Concerns::StreamProcessing
    include Concerns::ResultParsing
    include Concerns::InstructionBuilding

    INACTIVITY_TIMEOUT = 1200 # 20 minutes - kill only if stream_line_count stops changing
    HEARTBEAT_INTERVAL = 120 # 2 minutes between heartbeat messages

    def initialize(verbose: false, model_override: nil, resuming: false, **)
      @verbose = verbose
      @model_override = model_override
      @resuming = resuming
      @stopping = false
      @retry_state = Concerns::RetryHandling::RetryState.initial
      @api_overload_flag = false
      @result_received = false
      @inactivity_timeout = false
      @child_pid = nil
      @stream_line_count = 0
      @active_tool_calls = {}
      @log_tag = self.class.name.split('::').last
      OutputFormatter.verbose_mode = verbose
    end

    def run
      Logger.info_stdout "[#{@log_tag}] Starting execution..."
      Logger.info_stdout "[#{@log_tag}] Output mode: #{@verbose ? 'VERBOSE' : 'NORMAL'}"
      start_time = Time.now
      @accumulated_output = ''.dup
      @text_content = ''.dup

      run_with_retry(start_time)
    end

    private

    def attempt_execution(start_time)
      claude_path = resolve_claude_path
      instructions = @retry_state.marker_retry_mode ? build_marker_retry_instructions : build_instructions
      command = build_command(claude_path, instructions, continue_session: @retry_state.count.positive? || @retry_state.marker_retry_mode)

      Logger.debug "[#{@log_tag}] Executing Claude with instructions (length: #{instructions.length} chars)"
      Logger.info_stdout "[#{@log_tag}] Starting real-time stream of Claude output:"
      Logger.info_stdout "[#{@log_tag}] Retry attempt: #{@retry_state.count + 1}/#{MAX_RETRY_ATTEMPTS}" if @retry_state.count.positive?
      Logger.info_stdout "[#{@log_tag}] Marker retry mode: ON" if @retry_state.marker_retry_mode
      Logger.info_stdout '-' * 80

      @stopping = false
      stdout_content = execute_with_streaming(command)
      @accumulated_output << stdout_content

      Logger.info_stdout '-' * 80
      Logger.info_stdout "[#{@log_tag}] Claude execution completed, parsing results..."

      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)
      Logger.info_stdout "[#{@log_tag}] Elapsed time: #{elapsed_hours} hours"

      result = parse_result(@accumulated_output, elapsed_hours)

      # Detect API overload - Claude crashed due to 529 errors, not a real failure
      raise ApiOverloadError if api_overload_detected?

      # If marker not found and Claude completed successfully, retry with marker-only instruction
      raise MissingMarkerError if result['status'] == 'error' && result['message'].include?('WVRUNNER_RESULT')

      result
    rescue Timeout::Error
      handle_recoverable_error('Timeout', start_time)
    rescue StreamClosedError => e
      raise ApiOverloadError if @api_overload_flag

      handle_recoverable_error("Stream closed: #{e.message}", start_time)
    rescue MissingMarkerError
      handle_marker_retry(start_time)
    rescue ApiOverloadError
      handle_api_overload(start_time)
    end

    def resolve_claude_path
      Logger.debug "[#{@log_tag}] Resolving Claude executable path..."
      claude_path = ENV['CLAUDE_PATH'] || find_claude_executable
      raise 'Claude executable not found. Set CLAUDE_PATH environment variable.' unless claude_path

      Logger.info_stdout "[#{@log_tag}] Found Claude at: #{claude_path}"
      claude_path
    end

    def build_command(claude_path, instructions, continue_session: false)
      cmd = [claude_path]
      cmd << '--continue' if continue_session
      cmd.concat(['-p', instructions, '--model', effective_model_name, '--output-format=stream-json', '--verbose'])
      cmd << '--permission-mode=bypassPermissions' if accept_edits?
      Logger.debug "command: #{cmd.map { |arg| Shellwords.escape(arg) }.join(' ')}"
      cmd
    end

    def accept_edits?
      true # Override in subclass if needed
    end

    def effective_model_name
      @model_override || model_name
    end

    def reset_streaming_state
      @result_received = false
      @inactivity_timeout = false
      @api_overload_flag = false
      @stream_line_count = 0
      @active_tool_calls = {}
      @child_pid = nil
    end

    def execute_with_streaming(command)
      stdout_content = ''.dup
      stderr_content = ''.dup
      stream_error = nil
      reset_streaming_state
      execution_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      Open3.popen3(*command, pgroup: true) do |stdin, stdout, stderr, wait_thr|
        @child_pid = wait_thr.pid
        stdin.close

        stdout_thread = Thread.new do
          stream_lines(stdout) do |line|
            stdout_content << line.dup
            @stream_line_count += 1
            @text_content << extract_text_from_line(line)
            track_tool_event(line)
            check_for_mcp_server_status(line)
            check_for_api_overload(line)
            check_for_result_message(line)
            if OutputFormatter.should_log_to_stdout?(line)
              formatted = OutputFormatter.format_line(line)
              puts formatted
              Logger.info(formatted)
            else
              Logger.debug("[#{@log_tag}] [streaming] #{line.strip}")
            end
          end
        rescue IOError, Errno::EBADF => e
          handle_stream_error(e, 'stdout') { |err| stream_error = err }
        rescue StandardError => e
          Logger.error "[#{@log_tag}] stdout thread crashed: #{e.class}: #{e.message}"
          stream_error = "stdout thread crashed: #{e.message}" unless @stopping
        end

        stderr_thread = Thread.new do
          stream_lines(stderr) do |line|
            Logger.warn "\n[Claude STDERR] #{line}"
            stderr_content << line.dup
          end
        rescue IOError, Errno::EBADF => e
          handle_stream_error(e, 'stderr') { |err| stream_error ||= err }
        rescue StandardError => e
          Logger.error "[#{@log_tag}] stderr thread crashed: #{e.class}: #{e.message}"
        end

        heartbeat_thread = Thread.new do
          last_known_count = @stream_line_count
          last_activity_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          loop do
            sleep(HEARTBEAT_INTERVAL)
            break if @result_received || @stopping

            current_count = @stream_line_count
            now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

            if current_count != last_known_count
              last_known_count = current_count
              last_activity_time = now
            end

            inactive_seconds = (now - last_activity_time).to_i
            tool_info = format_active_tools(now)

            Logger.info_stdout "[#{@log_tag}] [heartbeat] Claude is working... " \
                               "(#{current_count} stream events, inactive: #{inactive_seconds}s#{tool_info})"

            next unless inactive_seconds >= INACTIVITY_TIMEOUT

            Logger.error "[#{@log_tag}] Claude inactive for #{inactive_seconds}s " \
                         "(stream count stuck at #{current_count}), terminating..."
            write_debug_dump(stderr_content, wait_thr.pid)
            @stopping = true
            @inactivity_timeout = true
            kill_process(wait_thr.pid)
            release_test_lock
            break
          end
        rescue StandardError => e
          Logger.debug "[#{@log_tag}] Heartbeat thread error: #{e.message}"
        end

        begin
          # Kill process first if result received, so streams close and threads unblock
          kill_process(wait_thr.pid) if @result_received

          stdout_thread.join
          stderr_thread.join(30)

          # Check if stream was unexpectedly closed
          raise StreamClosedError, stream_error if stream_error && !@stopping

          # Check if heartbeat detected inactivity
          raise Timeout::Error, "Claude inactive for #{INACTIVITY_TIMEOUT}s" if @inactivity_timeout

          exit_status = wait_for_process(wait_thr)
          if exit_status
            Logger.debug "[#{@log_tag}] Process exit status: #{exit_status.exitstatus}"

            if exit_status.exitstatus != 0 && !@result_received
              Logger.debug "[#{@log_tag}] WARNING: Claude exited with non-zero status!"
              Logger.debug "[#{@log_tag}] stderr: #{stderr_content}" unless stderr_content.empty?
            end
          end
        ensure
          heartbeat_thread&.kill
          kill_process(wait_thr.pid) unless @result_received
        end
      end

      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - execution_start).round(1)
      Logger.info_stdout "[#{@log_tag}] Execution finished in #{elapsed}s (#{@stream_line_count} stream events)"

      stdout_content
    end

    def build_instructions
      raise NotImplementedError, "#{self.class} must implement build_instructions"
    end

    def model_name
      raise NotImplementedError, "#{self.class} must implement model_name"
    end

    def error_result(message)
      Logger.debug "[#{@log_tag}] [error_result] Creating error result: #{message}"
      { 'status' => 'error', 'message' => message }
    end

    def release_test_lock
      test_lock = File.expand_path('~/.claude/bin/test_lock')
      return unless File.executable?(test_lock)

      system(test_lock, 'release')
    rescue StandardError => e
      Logger.warn "[#{@log_tag}] Failed to release test lock: #{e.message}"
    end

    def find_claude_executable
      Logger.debug "[#{@log_tag}] [find_claude_executable] Searching for Claude executable..."
      paths = %w[~/.claude/local/claude ~/.local/bin/claude /usr/local/bin/claude /opt/homebrew/bin/claude]

      paths.each do |path|
        expanded_path = File.expand_path(path)
        Logger.debug "[#{@log_tag}] [find_claude_executable] Checking: #{expanded_path}"
        if File.executable?(expanded_path)
          Logger.debug "[#{@log_tag}] [find_claude_executable] Found executable Claude at: #{expanded_path}"
          return expanded_path
        else
          Logger.debug "[#{@log_tag}] [find_claude_executable] Not found or not executable: #{expanded_path}"
        end
      end

      Logger.debug "[#{@log_tag}] [find_claude_executable] Trying 'which claude' fallback..."
      which_path = find_claude_via_which
      if which_path
        Logger.debug "[#{@log_tag}] [find_claude_executable] Found executable Claude via 'which': #{which_path}"
        return which_path
      end

      Logger.debug "[#{@log_tag}] [find_claude_executable] ERROR: Claude executable not found in any standard locations"
      nil
    end

    def find_claude_via_which
      output = IO.popen(['which', 'claude'], &:read).strip
      return output if output && !output.empty? && File.executable?(output)

      nil
    rescue StandardError => e
      Logger.debug "[#{@log_tag}] [find_claude_via_which] Error running 'which claude': #{e.message}"
      nil
    end

    def project_relative_id
      return nil unless File.exist?('CLAUDE.md')

      File.read('CLAUDE.md').match(/project_relative_id=(\d+)/)&.then { |m| m[1].to_i }
    end
  end
end
