# frozen_string_literal: true

module McptaskRunner
  module Concerns
    # Handles real-time stream processing: stdout/stderr reading, tool tracking, result detection, debug dumps
    module StreamProcessing
      private

      def stream_lines(io)
        io.each_line do |line|
          yield line
          break if @result_received
        end
      end

      def handle_stream_error(error, stream_name)
        return if @stopping # Expected closure during timeout/shutdown

        error_msg = "#{stream_name} stream closed unexpectedly: #{error.message}"
        Logger.warn "[#{@log_tag}] #{error_msg}"
        yield error_msg
      end

      def track_tool_event(line)
        parsed = JSON.parse(line)
        content_items = parsed.dig('message', 'content')
        return unless content_items.is_a?(Array)

        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        content_items.each do |item|
          case item['type']
          when 'tool_use'
            @active_tool_calls[item['id']] = { name: item['name'], started_at: now }
            Logger.debug "[#{@log_tag}] [tool_tracking] Tool started: #{item['name']} (#{item['id']})"
          when 'tool_result'
            removed = @active_tool_calls.delete(item['tool_use_id'])
            if removed
              duration = (now - removed[:started_at]).round(1)
              Logger.debug "[#{@log_tag}] [tool_tracking] Tool finished: #{removed[:name]} after #{duration}s"
            end
          end
        end
      rescue JSON::ParserError
        # Not JSON, ignore
      end

      def format_active_tools(now = nil)
        return '' if @active_tool_calls.empty?

        now ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
        tools = @active_tool_calls.map do |_id, info|
          duration = (now - info[:started_at]).to_i
          "#{info[:name]} since #{duration}s"
        end
        ", waiting for: #{tools.join(', ')}"
      end

      def check_for_mcp_server_status(line)
        return unless line.include?('"subtype":"init"')

        parsed = JSON.parse(line)
        servers = parsed['mcp_servers']
        return unless servers.is_a?(Array)

        servers.each do |server|
          next unless server['status'] == 'failed'

          Logger.warn "[#{@log_tag}] MCP server '#{server['name']}' failed to initialize!"
          Logger.info_stdout "[#{@log_tag}] WARNING: MCP server '#{server['name']}' is unavailable — agent will use fallback tools"
        end
      rescue JSON::ParserError
        # Not valid JSON, ignore
      end

      def check_for_api_overload(line)
        return if @api_overload_flag

        @api_overload_flag = true if line.include?('"error_status": 529') ||
                                     line.include?('"error_status":529') ||
                                     line.include?('Repeated 529 Overloaded')
      end

      def check_for_result_message(line)
        return if @result_received

        parsed = JSON.parse(line)
        return unless parsed['type'] == 'result'

        result_text = parsed['result'].to_s
        if result_text.include?('WVRUNNER_RESULT')
          @result_received = true
          @stopping = true
          Logger.info_stdout "[#{@log_tag}] Final result received (WVRUNNER_RESULT found), stopping streams..."
        else
          Logger.info_stdout "[#{@log_tag}] Interim result received (no WVRUNNER_RESULT), continuing to stream..."
        end
      rescue JSON::ParserError
        # Not JSON or invalid, ignore
      end

      def extract_text_from_line(line)
        parsed = JSON.parse(line)
        if (content = parsed.dig('message', 'content'))
          content.select { |item| item['type'] == 'text' }
                 .map { |item| item['text'] }
                 .join
        elsif parsed.dig('delta', 'type') == 'text_delta'
          parsed.dig('delta', 'text') || ''
        else
          ''
        end
      rescue JSON::ParserError
        ''
      end

      def write_debug_dump(stderr_content, pid)
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        dump_path = "log/debug_dump_#{timestamp}.txt"
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        sections = []
        sections << "=== DEBUG DUMP #{Time.now} ==="
        sections << "Stream event count: #{@stream_line_count}"
        sections << "Child PID: #{pid}"
        sections << ""

        sections << "=== ACTIVE TOOL CALLS ==="
        if @active_tool_calls.empty?
          sections << "(none)"
        else
          @active_tool_calls.each do |id, info|
            duration = (now - info[:started_at]).to_i
            sections << "  #{info[:name]} (#{id}) - waiting #{duration}s"
          end
        end
        sections << ""

        sections << "=== PROCESS TREE ==="
        sections << capture_process_tree(pid)
        sections << ""

        sections << "=== STDERR ==="
        sections << (stderr_content.empty? ? '(empty)' : stderr_content)
        sections << ""

        sections << "=== LAST 50 STREAM LINES ==="
        last_lines = (@text_content || '').lines.last(50)
        sections << (last_lines.empty? ? '(empty)' : last_lines.join)

        FileUtils.mkdir_p('log')
        File.write(dump_path, sections.join("\n"))
        Logger.info_stdout "[#{@log_tag}] Debug dump written to #{dump_path}"
      rescue StandardError => e
        Logger.warn "[#{@log_tag}] Failed to write debug dump: #{e.message}"
      end

      def capture_process_tree(pid)
        return '(no pid)' unless pid

        output = `ps -o pid,ppid,state,command -g #{pid} 2>&1`.strip
        output.empty? ? '(no processes found)' : output
      rescue StandardError => e
        "(error: #{e.message})"
      end
    end
  end
end
