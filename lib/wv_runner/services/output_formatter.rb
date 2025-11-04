# frozen_string_literal: true

require 'json'

module WvRunner
  # Formats Claude output for better readability
  class OutputFormatter
    def self.format_line(line)
      formatted = process_line(line)
      # Add blank line before [Claude] prefix, return unfrozen string
      "\n[Claude] #{formatted}".dup
    end

    def self.process_line(line)
      # Try to detect and format JSON
      if json_like?(line)
        format_json(line)
      else
        # Handle literal \n sequences as actual newlines
        process_newlines(line)
      end
    end

    def self.json_like?(line)
      line.strip.start_with?('{') && line.strip.end_with?('}')
    end

    def self.format_json(json_string)
      parsed = JSON.parse(json_string)
      # Pretty print with 2-space indentation
      JSON.pretty_generate(parsed)
    rescue JSON::ParserError
      # If parsing fails, try to handle escaped JSON
      unescaped = unescape_json(json_string)
      begin
        parsed = JSON.parse(unescaped)
        JSON.pretty_generate(parsed)
      rescue JSON::ParserError
        # If still fails, return original with newline processing
        process_newlines(json_string)
      end
    end

    def self.unescape_json(json_string)
      # Handle multiple levels of backslash escaping
      result = json_string
      result = result.gsub(/\\\\/, '\\') while result.include?('\\\\')
      result = result.gsub(/\\(["\\])/, '\1') while result.include?('\\')
      result
    end

    def self.process_newlines(text)
      # Convert literal \n to actual newlines for better readability
      text.gsub('\\n', "\n")
    end
  end
end
