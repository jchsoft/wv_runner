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
      results = []
      user_info = load_user_info

      loop do
        puts "Running task iteration..."
        result = ClaudeCode.new.run
        results << result
        puts "Task result: #{result.inspect}"

        decider = Decider.new(user_info: user_info, task_results: results)
        break if end_of_day? || decider.should_stop?

        puts "Remaining hours today: #{decider.remaining_hours}h"
        sleep(2)
      end

      results
    end

    def run_daily
      results = []
      user_info = load_user_info

      loop do
        puts "Running daily iteration..."
        result = ClaudeCode.new.run
        results << result

        decider = Decider.new(user_info: user_info, task_results: results)
        break if decider.should_stop?

        sleep(2)
      end

      results
    end

    def end_of_day?
      Time.now.hour >= 23
    end

    def load_user_info
      # In a Rails app, this would use MCP to fetch from WorkVector
      # For now, return nil (Decider handles gracefully)
      # TODO: Integrate with WorkVector MCP to load actual user_info
      nil
    end

    def validate_how(how)
      return if VALID_HOW_VALUES.include?(how)

      raise ArgumentError, "Invalid 'how' value: #{how}. Must be one of: #{VALID_HOW_VALUES.join(', ')}"
    end
  end
end
