module WvRunner
  class ClaudeCode
    INSTRUCTIONS = 'work on next task, read it using mcp resource "...@next?project_relative_id=..."'.freeze

    def run
      claude_path = ENV['CLAUDE_PATH'] || find_claude_executable
      raise "Claude executable not found. Set CLAUDE_PATH environment variable." unless claude_path

      command = "#{claude_path} -p \"#{INSTRUCTIONS}\" --output-format=stream-json --verbose"
      system(command)
    end

    private

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
