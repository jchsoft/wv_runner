# frozen_string_literal: true

require 'json'

module WvRunner
  # Formats Claude output for better readability
  class OutputFormatter
    @@verbose_mode = false

    def self.verbose_mode=(value)
      @@verbose_mode = value
    end

    def self.verbose_mode
      @@verbose_mode
    end

    def self.format_line(line)
      formatted = verbose_mode ? process_line(line) : process_line_normal(line)
      # Add blank line before [Claude] prefix, return unfrozen string
      "\n[Claude] #{formatted}".dup
    end

    def self.should_log_to_stdout?(line)
      return true if verbose_mode  # In verbose mode, show everything

      return false unless json_like?(line)

      begin
        parsed = JSON.parse(line)

        # Hide system initialization messages
        return false if parsed['type'] == 'system' && parsed['subtype'] == 'init'

        # Hide result metadata (success/failure tracking)
        return false if parsed['type'] == 'result'

        # Hide session/uuid/metadata-only messages
        return false if parsed.key?('type') && parsed.keys.length < 5 && !parsed.dig('message', 'content')

        # Show messages with actual content
        return true if parsed.dig('message', 'content')

        # Show text content
        return true if parsed['type'] == 'text'

        # Everything else (including Claude's actual work output)
        true
      rescue JSON::ParserError
        true  # If we can't parse, show it (probably important)
      end
    end

    # Verbose mode: output entire JSON as before
    def self.process_line(line)
      if json_like?(line)
        format_json(line)
      else
        process_newlines(line)
      end
    end

    # Normal mode: filter and extract relevant content
    def self.process_line_normal(line)
      if json_like?(line)
        extract_message_content(line)
      else
        process_newlines(line)
      end
    end

    def self.extract_message_content(json_string)
      parsed = JSON.parse(json_string)
      # Navigate to message.content if it exists
      return format_json(json_string) unless parsed.dig('message', 'content')

      content_items = parsed['message']['content']
      return format_json(json_string) unless content_items.is_a?(Array)

      format_content_items(content_items)
    rescue JSON::ParserError
      unescaped = unescape_json(json_string)
      begin
        parsed = JSON.parse(unescaped)
        return format_json(json_string) unless parsed.dig('message', 'content')

        content_items = parsed['message']['content']
        return format_json(json_string) unless content_items.is_a?(Array)

        format_content_items(content_items)
      rescue JSON::ParserError
        process_newlines(json_string)
      end
    end

    def self.format_content_items(items)
      formatted_parts = items.flat_map do |item|
        case item['type']
        when 'text'
          format_text_content(item)
        when 'tool_use'
          format_tool_use_content(item)
        when 'tool_result'
          format_tool_result_content(item)
        else
          "#{item['type']}: #{item.inspect}"
        end
      end

      formatted_parts.join("\n\n")
    end

    def self.format_text_content(item)
      text = item['text'].to_s
      # Replace literal \n with actual newlines
      text = text.gsub('\\n', "\n")
      # Remove system-reminder tags and their content (not meant for user display)
      strip_system_reminders(text)
    end

    def self.strip_system_reminders(text)
      text.gsub(%r{<system-reminder>.*?</system-reminder>}m, '').strip
    end

    def self.format_tool_use_content(item)
      name = item['name'].to_s
      tool_id = item['id'].to_s
      input_text = item['input'].is_a?(Hash) ? JSON.pretty_generate(item['input']) : item['input'].inspect

      "Tool: #{name} (ID: #{tool_id})\nInput:\n#{input_text}"
    end

    def self.format_tool_result_content(item)
      is_error = item['is_error'] ? 'ERROR' : 'OK'
      result_type = item['type'].to_s
      content = item['content'].to_s

      "Tool Result (#{is_error}) [#{result_type}]:\n#{content}"
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
