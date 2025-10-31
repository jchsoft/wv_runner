require 'open3'
require 'json'

module WvRunner
  class ClaudeCode
    def run
      start_time = Time.now
      claude_path = ENV['CLAUDE_PATH'] || find_claude_executable
      raise "Claude executable not found. Set CLAUDE_PATH environment variable." unless claude_path

      stdout, = Open3.capture3("#{claude_path} -p \"#{instructions}\" --output-format=stream-json --verbose")
      parse_result(stdout, ((Time.now - start_time) / 3600.0).round(2))
    end

    private

    def instructions
      project_id = project_relative_id or raise "project_relative_id not found in CLAUDE.md"

      <<~INSTRUCTIONS
        Work on next task from: workvector://pieces/jchsoft/@next?project_relative_id=#{project_id}

        At the END of your work, output this JSON on a single line:
        WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": X, "task_estimated": Y}}

        How to get the data:
        1. Read workvector://user → use "hour_goal" value for per_day
        2. From the task you're working on → parse "duration_best" field (e.g., "1 hodina" → 1.0) for task_estimated
        3. Set status: "success" if task completed, "failure" if not completed
      INSTRUCTIONS
    end

    def project_relative_id
      return nil unless File.exist?('CLAUDE.md')

      File.read('CLAUDE.md').match(/project_relative_id=(\d+)/)&.then { |m| m[1].to_i }
    end

    def parse_result(stdout, elapsed_hours)
      marker = "WVRUNNER_RESULT: "
      index = stdout.index(marker) or return error_result("No WVRUNNER_RESULT found in output")

      json_str = stdout[(index + marker.length)..-1].strip
      json_end = find_json_end(json_str) or return error_result("Could not find complete JSON object")

      JSON.parse(json_str[0...json_end]).tap { |obj| obj["hours"]["task_worked"] = elapsed_hours }
    rescue JSON::ParserError => e
      error_result("Failed to parse JSON: #{e.message}")
    end

    def find_json_end(json_str)
      brace_count = 0
      json_str.each_char.with_index do |char, i|
        brace_count += 1 if char == '{'
        brace_count -= 1 if char == '}'
        return i + 1 if brace_count.zero? && char == '}'
      end
      nil
    end

    def error_result(message)
      { "status" => "error", "message" => message }
    end

    def find_claude_executable
      %w[~/.claude/local/claude /usr/local/bin/claude /opt/homebrew/bin/claude].find do |path|
        File.executable?(File.expand_path(path))
      end&.then { |path| File.expand_path(path) }
    end
  end
end
