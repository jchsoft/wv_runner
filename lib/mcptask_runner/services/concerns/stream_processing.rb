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
            summary = summarize_tool_input(item['name'], item['input'])
            @active_tool_calls[item['id']] = { name: item['name'], started_at: now, summary: summary }
            EventStream.emit("tool.started", { tool_name: item['name'], tool_id: item['id'], summary: summary })
            Logger.debug "[#{@log_tag}] [tool_tracking] Tool started: #{item['name']} (#{item['id']}) #{summary}"
            check_stall(@stall_detector&.observe_tool_use(item))
          when 'tool_result'
            removed = @active_tool_calls.delete(item['tool_use_id'])
            if removed
              duration = (now - removed[:started_at]).round(1)
              EventStream.emit("tool.finished", { tool_name: removed[:name], tool_id: item['tool_use_id'], summary: removed[:summary], duration_s: duration })
              Logger.debug "[#{@log_tag}] [tool_tracking] Tool finished: #{removed[:name]} after #{duration}s"
            end
            check_stall(@stall_detector&.observe_tool_result(item))
          end
        end
      rescue JSON::ParserError
        # Not JSON, ignore
      end

      def summarize_tool_input(name, input)
        return '' unless input.is_a?(Hash)

        raw = case name
              when 'Bash' then input['command']
              when 'Edit', 'Write', 'Read', 'NotebookEdit' then input['file_path'] || input['notebook_path']
              when 'Grep' then [input['pattern'], input['path']].compact.join(' in ')
              when 'Glob' then input['pattern']
              when 'WebFetch' then input['url']
              when 'WebSearch' then input['query']
              when 'Task' then input['description'] || input['subagent_type']
              when 'TodoWrite' then summarize_todos(input['todos'])
              else input['file_path'] || input['path'] || input['query'] || input['pattern'] || input['command'] || input.values.first
        end

        truncate_summary(raw.to_s)
      end

      def summarize_todos(todos)
        return '' unless todos.is_a?(Array)

        current = todos.find { |t| t['status'] == 'in_progress' } || todos.find { |t| t['status'] == 'pending' }
        current ? current['content'] : "#{todos.count} todos"
      end

      def truncate_summary(text)
        clean = text.to_s.tr("\n\r\t", ' ').squeeze(' ').strip
        clean.length > 120 ? "#{clean[0, 117]}..." : clean
      end

      def check_stall(stall)
        return unless stall
        return if @runtime_state[:stalled]

        @runtime_state[:stalled] = stall
        @stopping = true
        Logger.error "[#{@log_tag}] Stall detected: reason=#{stall.reason} signature=#{stall.signature} " \
                     "count=#{stall.count}#{" detail=#{stall.detail}" if stall.detail} — terminating for Opus escalation"
        emit_stall_event(stall)
        kill_process(@child_pid)
        release_test_lock
      end

      def emit_stall_event(stall)
        EventStream.emit('stall.detected', {
                           executor: @log_tag,
                           reason: stall.reason.to_s,
                           signature: stall.signature,
                           count: stall.count,
                           detail: stall.detail,
                           phase: 'stalled'
                         })
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
        return if @runtime_state[:api_overload]

        @runtime_state[:api_overload] = true if line.include?('"error_status": 529') ||
                                                line.include?('"error_status":529') ||
                                                line.include?('Repeated 529 Overloaded')
      end

      def check_for_context_overflow(line)
        return if @runtime_state[:context_overflow]
        return unless line.include?('Prompt is too long') ||
                      line.include?('prompt is too long') ||
                      line.include?('context_length_exceeded')

        @runtime_state[:context_overflow] = true
        @stopping = true
        Logger.error "[#{@log_tag}] Context overflow detected ('Prompt is too long') — session is dead, marking terminal"
      end

      def check_for_result_message(line)
        return if @result_received

        parsed = JSON.parse(line)
        return unless parsed['type'] == 'result'

        result_text = parsed['result'].to_s
        if result_text.include?('TASKRUNNER_RESULT')
          @result_received = true
          @stopping = true
          Logger.info_stdout "[#{@log_tag}] Final result received (TASKRUNNER_RESULT found), stopping streams..."
        else
          Logger.info_stdout "[#{@log_tag}] Interim result received (no TASKRUNNER_RESULT), continuing to stream..."
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
