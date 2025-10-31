require 'open3'
require 'json'

module WvRunner
  class ClaudeCode
    def run
      start_time = Time.now
      claude_path = ENV['CLAUDE_PATH'] || find_claude_executable
      raise "Claude executable not found. Set CLAUDE_PATH environment variable." unless claude_path

      command = "#{claude_path} -p \"#{instructions}\" --output-format=stream-json --verbose"
      stdout, stderr, status = Open3.capture3(command)

      elapsed_hours = ((Time.now - start_time) / 3600.0).round(2)

      parse_result(stdout, elapsed_hours)
    end

    private

    def instructions
      project_id = project_relative_id
      raise "project_relative_id not found in CLAUDE.md" unless project_id

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
      claude_md = File.join(Dir.pwd, 'CLAUDE.md')
      return nil unless File.exist?(claude_md)

      content = File.read(claude_md)
      match = content.match(/project_relative_id=(\d+)/)
      match ? match[1].to_i : nil
    end

    def parse_result(stdout, elapsed_hours)
      marker = "WVRUNNER_RESULT: "
      index = stdout.index(marker)
      return { "status" => "error", "message" => "No WVRUNNER_RESULT found in output" } unless index

      json_start = index + marker.length
      json_str = stdout[json_start..-1].strip

      # Find the complete JSON object by counting braces
      brace_count = 0
      json_end = nil
      json_str.each_char.with_index do |char, i|
        brace_count += 1 if char == '{'
        brace_count -= 1 if char == '}'
        if brace_count == 0 && char == '}'
          json_end = i + 1
          break
        end
      end

      if json_end
        json_obj = JSON.parse(json_str[0...json_end])
        json_obj["hours"]["task_worked"] = elapsed_hours
        json_obj
      else
        { "status" => "error", "message" => "Could not find complete JSON object" }
      end
    rescue JSON::ParserError => e
      { "status" => "error", "message" => "Failed to parse JSON: #{e.message}" }
    end

    def find_claude_executable
      # Try common locations
      %w[
        ~/.claude/local/claude
        /usr/local/bin/claude
        /opt/homebrew/bin/claude
      ].each do |path|
        expanded_path = File.expand_path(path)
        return expanded_path if File.executable?(expanded_path)
      end

      nil
    end
  end
end
