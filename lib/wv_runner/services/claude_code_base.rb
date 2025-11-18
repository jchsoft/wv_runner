# frozen_string_literal: true

require 'open3'
require 'json'
require 'shellwords'
require 'timeout'
require_relative 'output_formatter'

module WvRunner
  # Base class for all Claude Code workflow step executors
  # Handles common execution, streaming, and JSON parsing logic
  # Subclasses must implement:
  # - build_instructions(input_state) → returns instruction string
  class ClaudeCodeBase
    CLAUDE_EXECUTION_TIMEOUT = 3600 # 1 hour in seconds
    def initialize(verbose: false)
      @verbose = verbose
      OutputFormatter.verbose_mode = verbose
    end

    # Public interface for running a workflow step with optional input state
    def run(input_state = nil)
      Logger.info_stdout "[#{self.class.name}] Starting execution..."
      Logger.info_stdout "[#{self.class.name}] Output mode: #{@verbose ? 'VERBOSE' : 'NORMAL'}"
      start_time = Time.now

      Logger.debug "[#{self.class.name}] Resolving Claude executable path..."
      claude_path = ENV['CLAUDE_PATH'] || find_claude_executable
      raise 'Claude executable not found. Set CLAUDE_PATH environment variable.' unless claude_path

      Logger.info_stdout "[#{self.class.name}] Found Claude at: #{claude_path}"
      Logger.debug "[#{self.class.name}] Building instructions..."

      instructions = build_instructions(input_state)
      command = [claude_path, '-p', instructions, '--output-format=stream-json', '--verbose',
                 '--permission-mode=acceptEdits']
      Logger.debug "command: #{command.map { |arg| Shellwords.escape(arg) }.join(' ')}"
      Logger.debug "[#{self.class.name}] Executing Claude with instructions (length: #{instructions.length} chars)"
      Logger.info_stdout "[#{self.class.name}] Starting real-time stream of Claude output:"
      Logger.info_stdout '-' * 80

      stdout_content = execute_with_streaming(command)

      Logger.info_stdout '-' * 80
      Logger.info_stdout "[#{self.class.name}] Claude execution completed, parsing results..."

      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)
      Logger.info_stdout "[#{self.class.name}] Elapsed time: #{elapsed_hours} hours"

      parse_output(stdout_content, elapsed_hours)
    rescue Timeout::Error
      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)
      error_result("Claude execution timed out after #{CLAUDE_EXECUTION_TIMEOUT} seconds (#{elapsed_hours} hours)")
    end

    private

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

    def build_instructions(_input_state)
      raise NotImplementedError, "#{self.class} must implement build_instructions(input_state)"
    end

    def parse_output(stdout, elapsed_hours)
      Logger.debug "[#{self.class.name}] [parse_output] Starting to parse Claude output..."
      Logger.debug "[#{self.class.name}] [parse_output] Total output length: #{stdout.length} chars"

      marker = 'WORKFLOW_STATE: '
      Logger.debug "[#{self.class.name}] [parse_output] Searching for marker: '#{marker}'"

      index = stdout.index(marker)
      unless index
        Logger.debug "[#{self.class.name}] [parse_output] ERROR: Marker not found in output!"
        Logger.debug "[#{self.class.name}] [parse_output] Last 500 chars of output: #{stdout.last(500)}"
        return error_result('No WORKFLOW_STATE found in output')
      end

      Logger.debug "[#{self.class.name}] [parse_output] Marker found at index #{index}"

      after_marker = stdout[(index + marker.length)..]
      Logger.debug "[#{self.class.name}] [parse_output] Content after marker (first 300 chars): #{after_marker[0...300]}"

      brace_index = after_marker.index('{')
      unless brace_index
        Logger.debug "[#{self.class.name}] [parse_output] ERROR: No opening brace found after marker!"
        return error_result('Could not find JSON object after WORKFLOW_STATE marker')
      end

      Logger.debug "[#{self.class.name}] [parse_output] Opening brace found at index #{brace_index}"

      json_str = after_marker[brace_index..]
      Logger.debug "[#{self.class.name}] [parse_output] Extracted JSON string (first 200 chars): #{json_str[0...200]}"

      json_end = find_json_end(json_str)
      unless json_end
        Logger.debug "[#{self.class.name}] [parse_output] ERROR: Could not find JSON object boundaries!"
        Logger.debug "[#{self.class.name}] [parse_output] JSON string: #{json_str[0...300]}"
        return error_result('Could not find complete JSON object')
      end

      Logger.debug "[#{self.class.name}] [parse_output] JSON object ends at position #{json_end}"

      json_content = json_str[0...json_end].strip
      json_content = json_content.gsub('\"', '"')
      json_content = json_content.gsub('\\\"', '\"')
      Logger.debug "[#{self.class.name}] [parse_output] Final JSON content to parse: #{json_content}"

      begin
        result = JSON.parse(json_content).tap do |obj|
          obj['hours'] ||= {}
          obj['hours']['task_worked'] = elapsed_hours
        end
        Logger.debug "[#{self.class.name}] [parse_output] Successfully parsed result: #{result.inspect}"
        result
      rescue JSON::ParserError => e
        Logger.debug "[#{self.class.name}] [parse_output] ERROR: JSON parsing failed: #{e.message}"
        Logger.debug "[#{self.class.name}] [parse_output] Attempted to parse: #{json_content.inspect}"
        error_result("Failed to parse JSON: #{e.message}")
      end
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
      paths = %w[~/.claude/local/claude /usr/local/bin/claude /opt/homebrew/bin/claude]

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

      Logger.debug "[#{self.class.name}] [find_claude_executable] ERROR: Claude executable not found in any of the standard locations"
      nil
    end

    def project_relative_id
      return nil unless File.exist?('CLAUDE.md')

      File.read('CLAUDE.md').match(/project_relative_id=(\d+)/)&.then { |m| m[1].to_i }
    end

    def validate_state(state, required_keys)
      Logger.debug "[#{self.class.name}] [validate_state] Validating state with required keys: #{required_keys.inspect}"
      Logger.debug "[#{self.class.name}] [validate_state] State keys: #{state.keys.inspect}"

      missing_keys = required_keys.reject { |key| state.key?(key) }

      if missing_keys.any?
        error_msg = "Invalid state: missing required keys: #{missing_keys.join(', ')}"
        Logger.error "[#{self.class.name}] [validate_state] #{error_msg}"
        Logger.error "[#{self.class.name}] [validate_state] Received state: #{state.inspect}"
        return error_result(error_msg)
      end

      Logger.debug "[#{self.class.name}] [validate_state] State validation passed"
      nil
    end

    protected

    def inject_state_into_instructions(instructions_template, input_state = nil)
      return instructions_template unless input_state

      state_json = JSON.generate(input_state)
      instructions_template.gsub('{{WORKFLOW_STATE}}', state_json)
    end
  end
end
