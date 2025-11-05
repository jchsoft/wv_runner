# frozen_string_literal: true

require 'open3'
require 'json'
require 'shellwords'
require_relative 'output_formatter'

module WvRunner
  # Handles Claude Code execution with streaming output
  class ClaudeCode
    def initialize(verbose: false)
      @verbose = verbose
      OutputFormatter.verbose_mode = verbose
    end

    def run
      puts '[ClaudeCode] Starting ClaudeCode execution...'
      puts "[ClaudeCode] Output mode: #{@verbose ? 'VERBOSE' : 'NORMAL'}"
      start_time = Time.now

      puts '[ClaudeCode] Resolving Claude executable path...'
      claude_path = ENV['CLAUDE_PATH'] || find_claude_executable
      raise 'Claude executable not found. Set CLAUDE_PATH environment variable.' unless claude_path

      puts "[ClaudeCode] Found Claude at: #{claude_path}"
      puts '[ClaudeCode] Building instructions with project_id...'

      # Use array form of command for proper shell escaping
      command = [claude_path, '-p', instructions, '--output-format=stream-json', '--verbose']
      puts "[ClaudeCode] Executing Claude with instructions (length: #{instructions.length} chars)"
      puts '[ClaudeCode] Starting real-time stream of Claude output:'
      puts '-' * 80

      stdout_content = execute_with_streaming(command)

      puts '-' * 80
      puts '[ClaudeCode] Claude execution completed, parsing results...'

      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)
      puts "[ClaudeCode] Elapsed time: #{elapsed_hours} hours"

      parse_result(stdout_content, elapsed_hours)
    end

    def run_dry
      puts '[ClaudeCode] Starting ClaudeCode DRY RUN execution (task load only, no execution)...'
      puts "[ClaudeCode] Output mode: #{@verbose ? 'VERBOSE' : 'NORMAL'}"
      start_time = Time.now

      puts '[ClaudeCode] Resolving Claude executable path...'
      claude_path = ENV['CLAUDE_PATH'] || find_claude_executable
      raise 'Claude executable not found. Set CLAUDE_PATH environment variable.' unless claude_path

      puts "[ClaudeCode] Found Claude at: #{claude_path}"
      puts '[ClaudeCode] Building DRY RUN instructions with project_id...'

      # Use array form of command for proper shell escaping
      command = [claude_path, '-p', instructions_dry, '--output-format=stream-json', '--verbose']
      puts "[ClaudeCode] Executing Claude with DRY RUN instructions (length: #{instructions_dry.length} chars)"
      puts '[ClaudeCode] Starting real-time stream of Claude output:'
      puts '-' * 80

      stdout_content = execute_with_streaming(command)

      puts '-' * 80
      puts '[ClaudeCode] Claude execution completed, parsing results...'

      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)
      puts "[ClaudeCode] Elapsed time: #{elapsed_hours} hours"

      parse_result(stdout_content, elapsed_hours)
    end

    private

    def execute_with_streaming(command)
      stdout_content = ''.dup
      stderr_content = ''.dup

      Open3.popen3(*command) do |stdin, stdout, stderr, wait_thr|
        stdin.close

        # Stream stdout and stderr concurrently to avoid deadlocks
        stdout_thread = Thread.new do
          stdout.each_line do |line|
            puts OutputFormatter.format_line(line)
            stdout_content << line.dup
          end
        end

        stderr_thread = Thread.new do
          stderr.each_line do |line|
            puts "\n[Claude STDERR] #{line}"
            stderr_content << line.dup
          end
        end

        # Wait for both threads to complete
        stdout_thread.join
        stderr_thread.join

        exit_status = wait_thr.value
        puts "[ClaudeCode] Process exit status: #{exit_status.exitstatus}"

        if exit_status.exitstatus != 0
          puts '[ClaudeCode] WARNING: Claude exited with non-zero status!'
          puts "[ClaudeCode] stderr: #{stderr_content}" unless stderr_content.empty?
        end
      end

      stdout_content
    end

    def instructions
      project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'

      <<~INSTRUCTIONS
        Work on next task from: workvector://pieces/jchsoft/@next?project_relative_id=#{project_id}

        WORKFLOW:
        1. CREATE A NEW BRANCH at the start of the task (use task name as branch name, e.g., "feature/task-name" or "fix/issue-name")
        2. COMPLETE the task according to requirements
        3. CREATE A PULL REQUEST when the task is finished:
           - Use the format from .github/pull_request_template.md if exists
           - Include a clear summary of changes
           - Link to the task in WorkVector
           - Ensure all tests pass before requesting review

        At the END of your work, output this JSON on a single line:
        WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": X, "task_estimated": Y}}

        IMPORTANT: Output VALID JSON with proper string escaping. Any quotes in string values must be escaped as \".

        How to get the data:
        1. Read workvector://user → use "hour_goal" value for per_day
        2. From the task you're working on → parse "duration_best" field (e.g., "1 hodina" → 1.0) for task_estimated
        3. Set status: "success" if task completed, "failure" if not completed
      INSTRUCTIONS
    end

    def instructions_dry
      project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'

      <<~INSTRUCTIONS
        Load and display information about the next task from: workvector://pieces/jchsoft/@next?project_relative_id=#{project_id}

        WORKFLOW (DRY RUN - NO EXECUTION):
        1. Fetch the next task from WorkVector using the URL above
        2. DO NOT create a branch
        3. DO NOT modify any code
        4. DO NOT create a pull request
        5. Just read and display the task information

        At the END, output this JSON on a single line with task information:
        WVRUNNER_RESULT: {"status": "success", "task_info": {"name": "...", "id": ..., "description": "...", "status": "...", "priority": "...", "assigned_user": "...", "scrum_points": "..."}, "hours": {"per_day": X, "task_estimated": Y}}

        IMPORTANT: Output VALID JSON with proper string escaping. Any quotes in string values must be escaped as \".

        How to get the data:
        1. Read workvector://user → use "hour_goal" value for per_day
        2. From the task you're working on → extract: name, relative_id (as id), description, task_state (as status), priority, assigned_user, scrum_point (as scrum_points)
        3. For task_estimated: Extract "duration_best" field from the task data. Convert it to numeric hours:
           - If duration_best contains "hodina" or "hours" → extract the number (e.g., "3 hodiny" → 3.0)
           - If duration_best contains "den" or "day" → multiply by 8 hours per workday (e.g., "1 den" → 8.0)
           - If duration_best contains "týden" or "week" → multiply by 40 hours per workweek (e.g., "1 týden" → 40.0)
           - Use the smallest/first number as task_estimated (e.g., from "3.0 - 7.0 hodin", use 3.0)
           - DEBUG: Print "[DEBUG] duration_best: '<original_value>' → task_estimated: Y" before outputting the JSON
        4. Set status: "success" if task loaded successfully
      INSTRUCTIONS
    end

    def project_relative_id
      return nil unless File.exist?('CLAUDE.md')

      File.read('CLAUDE.md').match(/project_relative_id=(\d+)/)&.then { |m| m[1].to_i }
    end

    def parse_result(stdout, elapsed_hours)
      puts '[ClaudeCode] [parse_result] Starting to parse Claude output...'
      puts "[ClaudeCode] [parse_result] Total output length: #{stdout.length} chars"

      marker = 'WVRUNNER_RESULT: '
      puts "[ClaudeCode] [parse_result] Searching for marker: '#{marker}'"

      index = stdout.index(marker)
      unless index
        puts '[ClaudeCode] [parse_result] ERROR: Marker not found in output!'
        puts "[ClaudeCode] [parse_result] Last 500 chars of output: #{stdout.last(500)}"
        return error_result('No WVRUNNER_RESULT found in output')
      end

      puts "[ClaudeCode] [parse_result] Marker found at index #{index}"

      # Extract everything after the marker
      after_marker = stdout[(index + marker.length)..]
      puts "[ClaudeCode] [parse_result] Content after marker (first 300 chars): #{after_marker.truncate(300)}"

      # Find the first opening brace
      brace_index = after_marker.index('{')
      unless brace_index
        puts '[ClaudeCode] [parse_result] ERROR: No opening brace found after marker!'
        return error_result('Could not find JSON object after WVRUNNER_RESULT marker')
      end

      puts "[ClaudeCode] [parse_result] Opening brace found at index #{brace_index}"

      json_str = after_marker[brace_index..]
      puts "[ClaudeCode] [parse_result] Extracted JSON string (first 200 chars): #{json_str.truncate(200)}"

      json_end = find_json_end(json_str)
      unless json_end
        puts '[ClaudeCode] [parse_result] ERROR: Could not find JSON object boundaries!'
        puts "[ClaudeCode] [parse_result] JSON string: #{json_str.truncate(300)}"
        return error_result('Could not find complete JSON object')
      end

      puts "[ClaudeCode] [parse_result] JSON object ends at position #{json_end}"

      json_content = json_str[0...json_end].strip
      # Claude outputs JSON with escaped quotes: \" for delimiters and \\\" for quotes in values
      # Simply unescape all \" to " - this creates valid JSON:
      # {\"name\": \"text \\\"quoted\\\"\"} becomes {"name": "text \"quoted\""}
      json_content = json_content.gsub('\"', '"')
      puts "[ClaudeCode] [parse_result] Final JSON content to parse: #{json_content}"

      begin
        result = JSON.parse(json_content).tap { |obj| obj['hours']['task_worked'] = elapsed_hours }
        puts "[ClaudeCode] [parse_result] Successfully parsed result: #{result.inspect}"

        # DEBUG: Show extracted values
        if result['task_info']
          puts '[ClaudeCode] [parse_result] DEBUG: Extracted task_info:'
          puts "[ClaudeCode] [parse_result]   - name: #{result['task_info']['name']}"
          puts "[ClaudeCode] [parse_result]   - id: #{result['task_info']['id']}"
          puts "[ClaudeCode] [parse_result]   - status: #{result['task_info']['status']}"
        end
        if result['hours']
          puts '[ClaudeCode] [parse_result] DEBUG: Extracted hours:'
          puts "[ClaudeCode] [parse_result]   - per_day: #{result['hours']['per_day']}"
          puts "[ClaudeCode] [parse_result]   - task_estimated: #{result['hours']['task_estimated']}"
          puts "[ClaudeCode] [parse_result]   - task_worked: #{result['hours']['task_worked']}"
        end

        result
      rescue JSON::ParserError => e
        puts "[ClaudeCode] [parse_result] ERROR: JSON parsing failed: #{e.message}"
        puts "[ClaudeCode] [parse_result] Attempted to parse: #{json_content.inspect}"
        error_result("Failed to parse JSON: #{e.message}")
      end
    end

    def find_json_end(json_str)
      puts "[ClaudeCode] [find_json_end] Searching for JSON object end, string length: #{json_str.length}"
      brace_count = 0
      i = 0

      while i < json_str.length
        char = json_str[i]

        # Handle various escaped quote sequences:
        # \\" (backslash followed by escaped quote)
        # \" (single backslash then quote)
        if char == '\\'
          # Count consecutive backslashes
          backslash_count = 0
          j = i
          while j < json_str.length && json_str[j] == '\\'
            backslash_count += 1
            j += 1
          end

          # If odd number of backslashes before a quote, the quote is escaped
          # If even number of backslashes before a quote, the quote is not escaped
          if j < json_str.length && json_str[j] == '"' && backslash_count.odd?
            # Skip the backslashes and the escaped quote
            i = j + 1
            next
          end
        end

        if char == '{'
          brace_count += 1
          puts "[ClaudeCode] [find_json_end] Found '{' at index #{i}, brace_count: #{brace_count}"
        elsif char == '}'
          brace_count -= 1
          puts "[ClaudeCode] [find_json_end] Found '}' at index #{i}, brace_count: #{brace_count}"
          if brace_count.zero?
            puts "[ClaudeCode] [find_json_end] JSON object complete at index #{i + 1}"
            return i + 1
          end
        end

        i += 1
      end
      puts "[ClaudeCode] [find_json_end] ERROR: JSON object not properly closed, final brace_count: #{brace_count}"
      nil
    end

    def error_result(message)
      puts "[ClaudeCode] [error_result] Creating error result: #{message}"
      { 'status' => 'error', 'message' => message }
    end

    def find_claude_executable
      puts '[ClaudeCode] [find_claude_executable] Searching for Claude executable...'
      paths = %w[~/.claude/local/claude /usr/local/bin/claude /opt/homebrew/bin/claude]

      paths.each do |path|
        expanded_path = File.expand_path(path)
        puts "[ClaudeCode] [find_claude_executable] Checking: #{expanded_path}"
        if File.executable?(expanded_path)
          puts "[ClaudeCode] [find_claude_executable] Found executable Claude at: #{expanded_path}"
          return expanded_path
        else
          puts "[ClaudeCode] [find_claude_executable] Not found or not executable: #{expanded_path}"
        end
      end

      puts '[ClaudeCode] [find_claude_executable] ERROR: Claude executable not found in any of the standard locations'
      nil
    end
  end
end
