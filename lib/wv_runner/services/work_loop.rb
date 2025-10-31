module WvRunner
  class WorkLoop
    VALID_HOW_VALUES = %i[once today daily].freeze

    def execute(how)
      validate_how(how)
      puts "WorkLoop executing with mode: #{how}"
      send("run_#{how}")
    end

    private

    def run_once
      result = ClaudeCode.new.run
      puts "Task completed: #{result.inspect}"
      result
    end

    def run_today
      loop do
        puts "Running task iteration..."
        result = ClaudeCode.new.run
        puts "Task result: #{result.inspect}"
        break if end_of_day? || should_stop?(result)
        sleep(2)
      end
    end

    def run_daily
      loop do
        puts "Running daily iteration..."
        ClaudeCode.new.run
        sleep(2)
      end
    end

    def end_of_day?
      Time.now.hour >= 23
    end

    def should_stop?(result)
      # Stop if status is error or if we've reached daily quota
      result["status"] == "error"
    end

    def validate_how(how)
      return if VALID_HOW_VALUES.include?(how)

      raise ArgumentError, "Invalid 'how' value: #{how}. Must be one of: #{VALID_HOW_VALUES.join(', ')}"
    end
  end
end
