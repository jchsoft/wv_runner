module WvRunner
  class ClaudeCode
    def run
      command = 'claude -p "read next task" --output-format=stream-json --verbose'
      system(command)
    end
  end
end
