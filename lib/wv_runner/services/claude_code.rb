module WvRunner
  class ClaudeCode
    def run
      command = '/Users/josefchmel/.claude/local/claude -p "read next task" --output-format=stream-json --verbose'
      system(command)
    end
  end
end
