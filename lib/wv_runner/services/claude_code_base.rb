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
    INACTIVITY_TIMEOUT = 1200 # 20 minutes - kill only if stream_line_count stops changing
    MAX_RETRY_ATTEMPTS = 3
    RETRY_WAIT_SECONDS = 30
    PROCESS_KILL_TIMEOUT = 5 # seconds to wait for SIGTERM before SIGKILL
    HEARTBEAT_INTERVAL = 120 # 2 minutes between heartbeat messages

    def initialize(verbose: false, model_override: nil, resuming: false)
      @verbose = verbose
      @model_override = model_override
      @resuming = resuming
      @stopping = false
      @retry_count = 0
      @marker_retry_mode = false
      @result_received = false
      @inactivity_timeout = false
      @child_pid = nil
      @stream_line_count = 0
      @log_tag = @log_tag
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

    def run_with_retry(start_time)
      loop do
        result = attempt_execution(start_time)
        return result if result

        @retry_count += 1
        break if @retry_count >= MAX_RETRY_ATTEMPTS

        Logger.info_stdout "[#{@log_tag}] Waiting #{RETRY_WAIT_SECONDS}s before retry #{@retry_count}/#{MAX_RETRY_ATTEMPTS}..."
        sleep(RETRY_WAIT_SECONDS)
      end

      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)
      error_result("Claude execution failed after #{MAX_RETRY_ATTEMPTS} retry attempts (#{elapsed_hours} hours)")
    end

    def attempt_execution(start_time)
      claude_path = resolve_claude_path
      instructions = @marker_retry_mode ? build_marker_retry_instructions : build_instructions
      command = build_command(claude_path, instructions, continue_session: @retry_count.positive? || @marker_retry_mode)

      Logger.debug "[#{@log_tag}] Executing Claude with instructions (length: #{instructions.length} chars)"
      Logger.info_stdout "[#{@log_tag}] Starting real-time stream of Claude output:"
      Logger.info_stdout "[#{@log_tag}] Retry attempt: #{@retry_count + 1}/#{MAX_RETRY_ATTEMPTS}" if @retry_count.positive?
      Logger.info_stdout "[#{@log_tag}] Marker retry mode: ON" if @marker_retry_mode
      Logger.info_stdout '-' * 80

      @stopping = false
      stdout_content = execute_with_streaming(command)
      @accumulated_output << stdout_content

      Logger.info_stdout '-' * 80
      Logger.info_stdout "[#{@log_tag}] Claude execution completed, parsing results..."

      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)
      Logger.info_stdout "[#{@log_tag}] Elapsed time: #{elapsed_hours} hours"

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
        Logger.error "[#{@log_tag}] #{error_type} - max retries reached"
        return error_result("#{error_type} after #{INACTIVITY_TIMEOUT}s inactivity (#{elapsed_hours}h), retries exhausted")
      end

      Logger.warn "[#{@log_tag}] #{error_type} after #{elapsed_hours}h - will retry with --continue"
      nil # Signal to retry
    end

    def handle_marker_retry(start_time)
      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)

      if @retry_count >= MAX_RETRY_ATTEMPTS - 1
        Logger.error "[#{@log_tag}] Missing marker - max retries reached"
        return error_result("Missing WVRUNNER_RESULT after retries exhausted (#{elapsed_hours}h)")
      end

      Logger.warn "[#{@log_tag}] Missing WVRUNNER_RESULT marker - will retry with marker-only instruction"
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

    def execute_with_streaming(command)
      stdout_content = ''.dup
      stderr_content = ''.dup
      stream_error = nil
      @result_received = false
      @inactivity_timeout = false
      @stream_line_count = 0
      @child_pid = nil
      execution_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      Open3.popen3(*command, pgroup: true) do |stdin, stdout, stderr, wait_thr|
        @child_pid = wait_thr.pid
        stdin.close

        stdout_thread = Thread.new do
          stream_lines(stdout) do |line|
            stdout_content << line.dup
            @stream_line_count += 1
            @text_content << extract_text_from_line(line)
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

            Logger.info_stdout "[#{@log_tag}] [heartbeat] Claude is working... " \
                               "(#{current_count} stream events, inactive: #{inactive_seconds}s)"

            next unless inactive_seconds >= INACTIVITY_TIMEOUT

            Logger.error "[#{@log_tag}] Claude inactive for #{inactive_seconds}s " \
                         "(stream count stuck at #{current_count}), terminating..."
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

          stdout_thread.join(30)
          stderr_thread.join(10)

          # Check if stream was unexpectedly closed
          raise StreamClosedError, stream_error if stream_error && !@stopping

          # Check if heartbeat detected inactivity
          raise Timeout::Error, "Claude inactive for #{INACTIVITY_TIMEOUT}s" if @inactivity_timeout

          exit_status = wait_thr.value
          Logger.debug "[#{@log_tag}] Process exit status: #{exit_status.exitstatus}"

          if exit_status.exitstatus != 0 && !@result_received
            Logger.debug "[#{@log_tag}] WARNING: Claude exited with non-zero status!"
            Logger.debug "[#{@log_tag}] stderr: #{stderr_content}" unless stderr_content.empty?
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

    def resolve_process_group(pid)
      Process.getpgid(pid)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end

    def safe_kill(signal, pid)
      Process.kill(signal, pid)
      true
    rescue Errno::ESRCH
      false
    end

    def kill_process(pid)
      return unless pid

      pgid = resolve_process_group(pid)
      kill_target = pgid ? -pgid : pid
      target_label = pgid ? "process group #{pgid}" : "pid #{pid}"

      Logger.info_stdout "[#{@log_tag}] Terminating Claude #{target_label}..."
      begin
        Process.kill('TERM', kill_target)
      rescue Errno::ESRCH
        return
      rescue Errno::EPERM
        Logger.warn "[#{@log_tag}] No permission to kill #{target_label}, falling back to pid #{pid}"
        safe_kill('TERM', pid) || return
      end

      PROCESS_KILL_TIMEOUT.times do
        sleep(1)
        begin
          Process.kill(0, pid)
        rescue Errno::ESRCH
          Logger.debug "[#{@log_tag}] Process #{pid} terminated after SIGTERM"
          return
        end
      end

      Logger.warn "[#{@log_tag}] Process #{pid} not responding to SIGTERM, sending SIGKILL..."
      begin
        Process.kill('KILL', kill_target)
      rescue Errno::ESRCH, Errno::EPERM
        safe_kill('KILL', pid)
      end
    rescue StandardError => e
      Logger.warn "[#{@log_tag}] Error during process cleanup: #{e.message}"
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
      Logger.warn "[#{@log_tag}] #{error_msg}"
      yield error_msg
    end

    def check_for_result_message(line)
      return if @result_received

      parsed = JSON.parse(line)
      return unless parsed['type'] == 'result'

      @result_received = true
      @stopping = true # Mark as expected shutdown
      Logger.info_stdout "[#{@log_tag}] Result received, stopping streams..."
    rescue JSON::ParserError
      # Not JSON or invalid, ignore
    end

    def build_instructions
      raise NotImplementedError, "#{self.class} must implement build_instructions"
    end

    def model_name
      raise NotImplementedError, "#{self.class} must implement model_name"
    end

    def extract_text_from_line(line)
      parsed = JSON.parse(line)
      if (content = parsed.dig('message', 'content'))
        content.select { |item| item['type'] == 'text' }
               .map { |item| item['text'] }
               .join
      elsif parsed.dig('delta', 'type') == 'text_delta'
        parsed.dig('delta', 'text') || ''
      else
        ''
      end
    rescue JSON::ParserError
      ''
    end

    def parse_result(stdout, elapsed_hours)
      Logger.debug "[#{@log_tag}] [parse_result] Starting to parse Claude output..."

      # Prefer clean extracted text over raw stream-json
      source = @text_content && !@text_content.empty? ? @text_content : stdout
      from_text_content = source.equal?(@text_content)
      Logger.debug "[#{@log_tag}] [parse_result] Using #{from_text_content ? 'extracted text' : 'raw stream-json'} (#{source.length} chars)"

      # Find WVRUNNER_RESULT marker - either as JSON key or legacy prefix
      json_content, from_text_content = find_result_marker(source, stdout, from_text_content)

      unless json_content
        Logger.debug "[#{@log_tag}] [parse_result] ERROR: Marker not found in output!"
        Logger.debug "[#{@log_tag}] [parse_result] Last 500 chars: #{(from_text_content ? source : stdout).last(500)}"
        return error_result('No WVRUNNER_RESULT found in output')
      end

      # Only unescape when parsing raw stream-json (text content is already clean)
      unless from_text_content
        json_content = json_content.gsub('\"', '"')
        json_content = json_content.gsub('\\\"', '\"')
      end

      Logger.debug "[#{@log_tag}] [parse_result] Final JSON content to parse: #{json_content}"

      begin
        result = JSON.parse(json_content).tap do |obj|
          obj.delete('WVRUNNER_RESULT')
          obj['hours'] ||= {}
          obj['hours']['task_worked'] = elapsed_hours
        end
        Logger.debug "[#{@log_tag}] [parse_result] Successfully parsed result: #{result.inspect}"
        log_task_info(result)
        result
      rescue JSON::ParserError => e
        Logger.debug "[#{@log_tag}] [parse_result] ERROR: JSON parsing failed: #{e.message}"
        Logger.debug "[#{@log_tag}] [parse_result] Attempted to parse: #{json_content.inspect}"
        error_result("Failed to parse JSON: #{e.message}")
      end
    end

    # Searches for WVRUNNER_RESULT in source text, trying JSON key format first, then legacy prefix.
    # Returns [json_string, from_text_content] or [nil, from_text_content].
    def find_result_marker(source, stdout, from_text_content)
      # Try JSON key format: {"WVRUNNER_RESULT": true, ...}
      json = extract_json_with_marker_key(source, from_text_content)
      return json if json

      # Fall back to raw stdout for JSON key format
      if from_text_content
        json = extract_json_with_marker_key(stdout, false)
        return json if json
      end

      # Legacy prefix format: WVRUNNER_RESULT: {json}
      json = extract_json_with_legacy_prefix(source, from_text_content)
      return json if json

      if from_text_content
        json = extract_json_with_legacy_prefix(stdout, false)
        return json if json
      end

      [nil, from_text_content]
    end

    def extract_json_with_marker_key(source, from_text_content)
      key_index = source.index('"WVRUNNER_RESULT"')
      return nil unless key_index

      # Walk backward to find opening brace
      i = key_index - 1
      i -= 1 while i >= 0 && source[i] =~ /\s/
      return nil unless i >= 0 && source[i] == '{'

      json_str = source[i..]
      json_end = find_json_end(json_str)
      return nil unless json_end

      Logger.debug "[#{@log_tag}] [parse_result] JSON key marker found at index #{key_index}"
      [json_str[0...json_end].strip, from_text_content]
    end

    def extract_json_with_legacy_prefix(source, from_text_content)
      marker = 'WVRUNNER_RESULT: '
      index = source.index(marker)
      return nil unless index

      after_marker = source[(index + marker.length)..]
      brace_index = after_marker.index('{')
      return nil unless brace_index

      json_str = after_marker[brace_index..]
      json_end = find_json_end(json_str)
      return nil unless json_end

      Logger.debug "[#{@log_tag}] [parse_result] Legacy prefix marker found at index #{index}"
      [json_str[0...json_end].strip, from_text_content]
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

      Logger.debug "[#{@log_tag}] [find_json_end] ERROR: JSON object not properly closed, final brace_count: #{brace_count}"
      nil
    end

    def error_result(message)
      Logger.debug "[#{@log_tag}] [error_result] Creating error result: #{message}"
      { 'status' => 'error', 'message' => message }
    end

    def triaged_git_step(resuming:)
      if resuming
        <<~STEP.strip
          1. RESUME IN-PROGRESS TASK:
             - You are resuming a task that is already in progress on the current feature branch.
             - Do NOT checkout main. Do NOT create a new branch.
             - Review git log and current code state to understand what was already done.
             - SKIP steps 2-3 (task fetch, branch creation) and go directly to step 4 (IMPLEMENT).
        STEP
      else
        <<~STEP.strip
          1. GIT SETUP:
             - Run: git checkout main && git pull
             - Proceed to step 2 (TASK FETCH)
        STEP
      end
    end

    def branch_resume_check_step(project_id:, pull_on_main: true)
      pull_cmd = pull_on_main ? 'git checkout main && git pull' : 'git checkout main'
      <<~STEP.strip
        1. GIT STATE AND RESUME CHECK:
           - Run: git branch --show-current
           - IF on "main" or "master":
             → Run: #{pull_cmd}
             → Proceed to step 2 (TASK FETCH)
           - IF on ANY OTHER branch (feature branch):
             a) TRY TO IDENTIFY TASK from branch name:
                - Branch names often contain task ID (e.g., "feature/9508-contact-page", "fix/9123-bug")
                - Extract numeric ID from branch name
                - If found: read workvector://pieces/jchsoft/{task_id} to load task details
             b) If no ID in branch name, check for open PR:
                - gh pr list --head $(git branch --show-current) --json body --jq '.[0].body'
                - Look for mcptask.online link → extract task ID → load task
             c) If STILL no task found:
                → #{pull_cmd} → proceed to step 2
             d) CHECK TASK PROGRESS (if task was found):
                - If progress >= 100 or state "Schváleno"/"Hotovo?":
                  → Task is done. #{pull_cmd} → proceed to step 2
                - If progress < 100:
                  → RESUME: display WVRUNNER_TASK_INFO, SKIP steps 2-3, go to step 4
      STEP
    end

    def coding_conventions_instruction
      <<~INSTRUCTION.strip
        CODING CONVENTIONS (MANDATORY):
        - GIT COMMITS: NEVER use $() command substitution in git commit messages.
          Always pass the message as a simple quoted string directly:
          ✅ git commit -m "Fix login validation for empty emails"
          ❌ git commit -m "$(echo 'Fix login')"
          ❌ git commit -m "$(cat some_file)"
          For multi-line messages, use heredoc:
          git commit -m "$(cat <<'EOF'
          Your message here.
          EOF
          )"
        - RUBOCOP BEFORE CI: Before running bin/ci, always run RuboCop autofix on changed .rb files:
          git diff --name-only main -- '*.rb' | xargs rubocop -a
          This prevents wasting CI cycles on style violations.
      INSTRUCTION
    end

    def result_format_instruction(json_fields, extra_rules: [])
      rules = [
        'The JSON MUST be inside a ```json code block on its own line',
        '"WVRUNNER_RESULT": true MUST be the FIRST key in the JSON object',
        'Output VALID JSON - any quotes in string values must be escaped as \\"',
        *extra_rules,
        'NO other text after the closing ```'
      ]

      numbered = rules.each_with_index.map { |rule, i| "#{i + 1}. #{rule}" }.join("\n")

      <<~INSTRUCTION.strip
        At the END, output the result as valid JSON in a code block:

        ```json
        {"WVRUNNER_RESULT": true, #{json_fields}}
        ```

        CRITICAL FORMATTING:
        #{numbered}
      INSTRUCTION
    end

    def time_awareness_instruction
      <<~INSTRUCTION.strip
        TIME MANAGEMENT (CRITICAL):
        - You should aim to complete within 90 minutes, but you will only be terminated if inactive for 20 minutes.
        - "Inactive" means no new stream output for 20 minutes straight - as long as you're producing output, you're safe.
        - Before starting any long-running step (system tests, full CI), consider elapsed time.
        - If more than 70 minutes have elapsed, SKIP full test suites and full CI.
          Instead: run only targeted tests for YOUR changes, then proceed to output WVRUNNER_RESULT.
        - ALWAYS prioritize outputting WVRUNNER_RESULT when your work is complete.
      INSTRUCTION
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
