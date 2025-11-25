# frozen_string_literal: true

require 'open3'
require 'json'
require 'shellwords'
require 'timeout'
require_relative 'output_formatter'

module WvRunner
  # Base class for Claude Code executors
  # Handles common execution, streaming, and JSON parsing logic
  # Subclasses must implement:
  # - build_instructions() -> returns instruction string
  # - model_name() -> returns the model to use (e.g., 'sonnet', 'haiku', 'opus')
  class ClaudeCodeBase
    CLAUDE_EXECUTION_TIMEOUT = 3600 # 1 hour in seconds

    def initialize(verbose: false)
      @verbose = verbose
      OutputFormatter.verbose_mode = verbose
    end

    def run
      Logger.info_stdout "[#{self.class.name}] Starting execution..."
      Logger.info_stdout "[#{self.class.name}] Output mode: #{@verbose ? 'VERBOSE' : 'NORMAL'}"
      start_time = Time.now

      claude_path = resolve_claude_path
      instructions = build_instructions
      command = build_command(claude_path, instructions)

      Logger.debug "[#{self.class.name}] Executing Claude with instructions (length: #{instructions.length} chars)"
      Logger.info_stdout "[#{self.class.name}] Starting real-time stream of Claude output:"
      Logger.info_stdout '-' * 80

      stdout_content = execute_with_streaming(command)

      Logger.info_stdout '-' * 80
      Logger.info_stdout "[#{self.class.name}] Claude execution completed, parsing results..."

      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)
      Logger.info_stdout "[#{self.class.name}] Elapsed time: #{elapsed_hours} hours"

      parse_result(stdout_content, elapsed_hours)
    rescue Timeout::Error
      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)
      error_result("Claude execution timed out after #{CLAUDE_EXECUTION_TIMEOUT} seconds (#{elapsed_hours} hours)")
    end

    private

    def resolve_claude_path
      Logger.debug "[#{self.class.name}] Resolving Claude executable path..."
      claude_path = ENV['CLAUDE_PATH'] || find_claude_executable
      raise 'Claude executable not found. Set CLAUDE_PATH environment variable.' unless claude_path

      Logger.info_stdout "[#{self.class.name}] Found Claude at: #{claude_path}"
      claude_path
    end

    def build_command(claude_path, instructions)
      cmd = [claude_path, '-p', instructions, '--model', model_name, '--output-format=stream-json', '--verbose']
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

      Timeout.timeout(CLAUDE_EXECUTION_TIMEOUT) do
        Open3.popen3(*command) do |stdin, stdout, stderr, wait_thr|
          stdin.close

          stdout_thread = Thread.new do
            stdout.each_line do |line|
              stdout_content << line.dup
              if OutputFormatter.should_log_to_stdout?(line)
                puts OutputFormatter.format_line(line)
              else
                Logger.debug("[#{self.class.name}] [streaming] #{line.strip}")
              end
            end
          end

          stderr_thread = Thread.new do
            stderr.each_line do |line|
              Logger.warn "\n[Claude STDERR] #{line}"
              stderr_content << line.dup
            end
          end

          stdout_thread.join
          stderr_thread.join

          exit_status = wait_thr.value
          Logger.debug "[#{self.class.name}] Process exit status: #{exit_status.exitstatus}"

          if exit_status.exitstatus != 0
            Logger.debug "[#{self.class.name}] WARNING: Claude exited with non-zero status!"
            Logger.debug "[#{self.class.name}] stderr: #{stderr_content}" unless stderr_content.empty?
          end
        end
      end

      stdout_content
    rescue Timeout::Error
      Logger.error "[#{self.class.name}] Claude execution timed out after #{CLAUDE_EXECUTION_TIMEOUT} seconds"
      raise
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
        Logger.debug "[#{self.class.name}] [parse_result] Last 500 chars of output: #{stdout.last(500)}"
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
