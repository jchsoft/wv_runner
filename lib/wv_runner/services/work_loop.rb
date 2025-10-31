module WvRunner
  class WorkLoop
    VALID_HOW_VALUES = %i[once today daily].freeze

    def execute(how)
      validate_how(how)
      puts "WorkLoop executing with mode: #{how}"
      ClaudeCode.new.run
    end

    private

    def validate_how(how)
      return if VALID_HOW_VALUES.include?(how)

      raise ArgumentError, "Invalid 'how' value: #{how}. Must be one of: #{VALID_HOW_VALUES.join(', ')}"
    end
  end
end
