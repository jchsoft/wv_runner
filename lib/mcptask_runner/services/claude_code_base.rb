# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'json'
require 'shellwords'
require 'timeout'
require_relative 'output_formatter'
require_relative 'stall_detector'
require_relative 'concerns/process_management'
require_relative 'concerns/retry_handling'
require_relative 'concerns/stream_processing'
require_relative 'concerns/result_parsing'
require_relative 'concerns/instruction_building'

module McptaskRunner
  # Raised when IO stream unexpectedly closes during Claude execution
  class StreamClosedError < StandardError; end

  # Raised when TASKRUNNER_RESULT marker is not found in output
  class MissingMarkerError < StandardError; end

  # Raised when Claude exits due to API overload (529 errors)
  class ApiOverloadError < StandardError; end

  # Raised when Claude session context exceeds 1M token limit ("Prompt is too long").
  # Terminal: session is unrecoverable, --continue on same session would re-trigger the error.
  class ContextOverflowError < StandardError; end

  # Raised when daily quota crosses per_day while a Claude run is in progress.
  # Terminal: heartbeat already SIGTERMed the subprocess; caller must NOT retry.
  class QuotaExceededMidTaskError < StandardError; end

  # Raised when StallDetector flags the session as spinning (repeated failed tool calls,
  # edit-failure streak, no progress in a window). Terminal: the task stays in_progress
  # so the next triage promotes to Opus via TriageExecution#upgrade_model_for_resume.
  class StalledError < StandardError
    attr_reader :stall

    def initialize(stall)
      super("Stalled: reason=#{stall.reason} signature=#{stall.signature} count=#{stall.count}")
      @stall = stall
    end
  end

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
    TOOL_HANG_TIMEOUT = 3600 # 60 minutes - long tools (Bash/Task): system tests/CI/subagents can run ~30min
    QUICK_TOOL_HANG_TIMEOUT = 120 # 2 minutes - fast tools (MCP, Read, Edit, Grep, ToolSearch...) should respond quickly;
    # catches MCP server hangs (e.g. mcptask.online restart drops connection mid-call)
    # without waiting the full hour the long-tool ceiling allows.
    LONG_RUNNING_TOOLS = %w[Bash Task].freeze

    # Pin to standard 200K-context model IDs (no [1m] suffix) so context overflows fail fast
    # at ~200K instead of growing to 1M across --continue retry chains.
    # Update IDs when newer models are released.
    MODEL_IDS = {
      'opus' => 'claude-opus-4-7',
      'sonnet' => 'claude-sonnet-4-6',
      'haiku' => 'claude-haiku-4-5-20251001'
    }.freeze

    # Set by WorkLoop before #run when mid-task quota guarding is desired.
    # Hash with :per_day_hours and :already_worked_hours (both Float).
    # nil = no guard (used by Triage / Review / Dry executors).
    def quota_watch=(val)
      @runtime_state[:quota_watch] = val
    end

    def initialize(verbose: false, model_override: nil, resuming: false, **)
      @verbose = verbose
      @model_override = model_override
      @resuming = resuming
      @stopping = false
      @retry_state = Concerns::RetryHandling::RetryState.initial
      @result_received = false
      @runtime_state = {
        quota_watch: nil, quota_exceeded: false, inactivity_timeout: false,
        api_overload: false, context_overflow: false, stalled: nil
      }
      @child_pid = nil
      @stream_line_count = 0
      @active_tool_calls = {}
      @log_tag = self.class.name.split('::').last
      @stall_detector = StallDetector.new(@log_tag)
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

      # Claude emitted TASKRUNNER_RESULT — trust its terminal output even if context-overflow
      # or 529 patterns appeared earlier in the stream. Those may be sub-agent or transient
      # errors Claude already recovered from; overriding here would discard a real success.
      return result if @result_received && !marker_parse_failed?(result)

      # Detect context overflow BEFORE other errors - session is dead, --continue cannot recover
      raise ContextOverflowError if context_overflow_detected?

      # Detect API overload - Claude crashed due to 529 errors, not a real failure
      raise ApiOverloadError if api_overload_detected?

      # If marker not found and Claude completed successfully, retry with marker-only instruction
      raise MissingMarkerError if marker_parse_failed?(result)

      result
    rescue Timeout::Error
      raise ContextOverflowError if @runtime_state[:context_overflow]

      handle_recoverable_error('Timeout', start_time)
    rescue StreamClosedError => e
      raise ContextOverflowError if @runtime_state[:context_overflow]
      raise ApiOverloadError if @runtime_state[:api_overload]

      handle_recoverable_error("Stream closed: #{e.message}", start_time)
    rescue MissingMarkerError
      handle_marker_retry(start_time)
    rescue ApiOverloadError
      handle_api_overload(start_time)
    rescue ContextOverflowError
      handle_context_overflow(start_time)
    rescue StalledError => e
      handle_stalled(e.stall, start_time)
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
      cmd.concat(['--max-turns', max_turns.to_s]) if max_turns
      cmd << '--permission-mode=bypassPermissions' if accept_edits?
      Logger.debug "command: #{cmd.map { |arg| Shellwords.escape(arg) }.join(' ')}"
      cmd
    end

    def accept_edits?
      true # Override in subclass if needed
    end

    # Per-invocation turn cap. Subclasses override; nil = no cap.
    def max_turns
      nil
    end

    def effective_model_name
      raw = @model_override || model_name
      MODEL_IDS.fetch(raw, raw)
    end

    def reset_streaming_state
      @result_received = false
      @runtime_state[:inactivity_timeout] = false
      @runtime_state[:quota_exceeded] = false
      @runtime_state[:api_overload] = false
      @runtime_state[:context_overflow] = false
      @runtime_state[:stalled] = nil
      @stream_line_count = 0
      @active_tool_calls = {}
      @child_pid = nil
      @stall_detector = StallDetector.new(@log_tag)
    end

    def quota_exceeded_now?(execution_start, now)
      watch = @runtime_state[:quota_watch] or return false

      per_day = watch[:per_day_hours].to_f
      return false unless per_day.positive?

      watch[:already_worked_hours].to_f + ((now - execution_start) / 3600.0) >= per_day
    end

    def raise_streaming_errors_if_any(stream_error)
      raise StalledError, @runtime_state[:stalled] if @runtime_state[:stalled]
      raise StreamClosedError, stream_error if stream_error && !@stopping
      raise Timeout::Error, "Claude inactive for #{INACTIVITY_TIMEOUT}s" if @runtime_state[:inactivity_timeout]
      raise QuotaExceededMidTaskError, 'daily quota exceeded during run' if @runtime_state[:quota_exceeded]
    end

    def log_exit_status(exit_status, stderr_content)
      return unless exit_status

      Logger.debug "[#{@log_tag}] Process exit status: #{exit_status.exitstatus}"
      return unless exit_status.exitstatus != 0 && !@result_received

      Logger.debug "[#{@log_tag}] WARNING: Claude exited with non-zero status!"
      Logger.debug "[#{@log_tag}] stderr: #{stderr_content}" unless stderr_content.empty?
    end

    def heartbeat_quota_terminate(execution_start, now)
      return false unless quota_exceeded_now?(execution_start, now)

      watch = @runtime_state[:quota_watch]
      elapsed_h = ((now - execution_start) / 3600.0).round(2)
      Logger.error "[#{@log_tag}] Daily quota exceeded mid-task " \
                   "(per_day=#{watch[:per_day_hours]}h, already_worked=#{watch[:already_worked_hours]}h, " \
                   "this_run=#{elapsed_h}h), terminating..."
      @stopping = true
      @runtime_state[:quota_exceeded] = true
      kill_process(@child_pid)
      release_test_lock
      true
    end

    def execute_with_streaming(command)
      stdout_content = ''.dup
      stderr_content = ''.dup
      stream_error = nil
      reset_streaming_state
      EventStream.emit("execution.started", { model: effective_model_name, phase: event_phase })
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
            check_for_context_overflow(line)
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
            check_for_context_overflow(line)
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

            # A running tool (e.g. long Bash/system test) is real activity even if Claude
            # stops streaming during it — reset the inactivity timer so we don't kill
            # healthy tasks and don't flap the UI badge to "stale". TOOL_HANG_TIMEOUT
            # below still kills if a single tool genuinely hangs forever.
            last_activity_time = now if @active_tool_calls.any?

            inactive_seconds = (now - last_activity_time).to_i
            tool_info = format_active_tools(now)

            Logger.info_stdout "[#{@log_tag}] [heartbeat] Claude is working... " \
                               "(#{current_count} stream events, inactive: #{inactive_seconds}s#{tool_info})"
            EventStream.emit("execution.heartbeat", {
                               stream_events: current_count,
                               inactive_s: inactive_seconds,
                               phase: event_phase,
                               active_tools: active_tool_names,
                               active_tools_count: @active_tool_calls.size
                             })

            break if heartbeat_quota_terminate(execution_start, now)

            if (hung = hung_tool(now))
              Logger.error "[#{@log_tag}] Tool '#{hung[:name]}' hung for #{(now - hung[:started_at]).to_i}s " \
                           "(>#{tool_hang_timeout_for(hung[:name])}s), terminating..."
              terminate_for_inactivity(stderr_content)
              break
            end

            next unless inactive_seconds >= INACTIVITY_TIMEOUT

            Logger.error "[#{@log_tag}] Claude inactive for #{inactive_seconds}s " \
                         "(stream count stuck at #{current_count}), terminating..."
            terminate_for_inactivity(stderr_content)
            break
          end
        rescue StandardError => e
          Logger.debug "[#{@log_tag}] Heartbeat thread error: #{e.message}"
        end

        begin
          # Kill process first if result received, so streams close and threads unblock
          kill_process(@child_pid) if @result_received

          stdout_thread.join
          stderr_thread.join(30)
          raise_streaming_errors_if_any(stream_error)
          log_exit_status(wait_for_process(wait_thr), stderr_content)
        ensure
          heartbeat_thread&.kill
          kill_process(@child_pid) unless @result_received
        end
      end

      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - execution_start).round(1)
      Logger.info_stdout "[#{@log_tag}] Execution finished in #{elapsed}s (#{@stream_line_count} stream events)"
      EventStream.emit("execution.completed", {
                         elapsed_s: elapsed,
                         stream_events: @stream_line_count,
                         phase: event_phase
                       })

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

    # Phase label attached to EventStream payloads so the UI can distinguish
    # triage runs from main task execution. Subclasses override for special phases.
    def event_phase
      'execution'
    end

    def active_tool_names
      @active_tool_calls.values.map { |info| info[:name] }
    end

    def terminate_for_inactivity(stderr_content)
      write_debug_dump(stderr_content, @child_pid)
      @stopping = true
      @runtime_state[:inactivity_timeout] = true
      kill_process(@child_pid)
      release_test_lock
    end

    def hung_tool(now)
      @active_tool_calls.values.find do |info|
        (now - info[:started_at]) >= tool_hang_timeout_for(info[:name])
      end
    end

    def tool_hang_timeout_for(name)
      LONG_RUNNING_TOOLS.include?(name) ? TOOL_HANG_TIMEOUT : QUICK_TOOL_HANG_TIMEOUT
    end

    def marker_parse_failed?(result)
      result['status'] == 'error' && result['message'].to_s.include?('TASKRUNNER_RESULT')
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
