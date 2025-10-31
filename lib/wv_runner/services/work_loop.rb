module WvRunner
  class WorkLoop
    VALID_HOW_VALUES = %i[once today daily].freeze

    def execute(how)
      validate_how(how)
      puts "WorkLoop executing with mode: #{how}"

      case how
      when :once
        run_once
      when :today
        run_until_end_of_day
      when :daily
        run_daily
      end
    end

    private

    def run_once
      ClaudeCode.new.run
    end

    def run_until_end_of_day
      loop do
        puts "Running task iteration..."
        ClaudeCode.new.run
        break if end_of_day?
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

    def validate_how(how)
      return if VALID_HOW_VALUES.include?(how)

      raise ArgumentError, "Invalid 'how' value: #{how}. Must be one of: #{VALID_HOW_VALUES.join(', ')}"
    end
  end
end
