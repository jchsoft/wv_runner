# frozen_string_literal: true

require "json"

module McptaskRunner
  # Streams runner events to mcptask.online via ActionCable WebSocket.
  # Disabled when WV_RUNNER_CABLE_URL env var is not set.
  module EventStream
    CHANNEL_IDENTIFIER = JSON.generate({ channel: "RunnerSessionChannel" })

    class << self
      def start_session(mode:)
        return unless enabled?

        @mode = mode
        @subscribed = false
        @mutex = Mutex.new
        @subscribed_cv = ConditionVariable.new

        connect
      rescue StandardError => e
        Logger.warn "[EventStream] Failed to start session: #{e.message}"
      end

      def emit(event_type, payload)
        return unless enabled? && @ws&.open?

        data = JSON.generate({
          action: "emit",
          event_type: event_type,
          payload: payload
        })

        @ws.send(JSON.generate({
          command: "message",
          identifier: CHANNEL_IDENTIFIER,
          data: data
        }))
      rescue StandardError => e
        Logger.warn "[EventStream] Failed to emit #{event_type}: #{e.message}"
      end

      def end_session
        return unless enabled? && @ws

        @ws.close
        @ws = nil
      rescue StandardError => e
        Logger.warn "[EventStream] Failed to end session: #{e.message}"
      end

      def enabled?
        !ENV.fetch("WV_RUNNER_CABLE_URL", "").empty?
      end

      private

      def connect
        require "websocket-client-simple"

        url = cable_url
        Logger.info_stdout "[EventStream] Connecting to ActionCable..."

        @ws = WebSocket::Client::Simple.connect(url) do |ws|
          ws.on(:open) do
            Logger.debug "[EventStream] WebSocket connected, subscribing..."
            ws.send(JSON.generate({ command: "subscribe", identifier: CHANNEL_IDENTIFIER }))
          end

          ws.on(:message) { |msg| handle_message(msg.data) }

          ws.on(:error) { |e| Logger.warn "[EventStream] WebSocket error: #{e.message}" }

          ws.on(:close) { Logger.debug "[EventStream] WebSocket closed" }
        end

        wait_for_subscription
      end

      def handle_message(data)
        return if data.nil? || data.empty?

        parsed = JSON.parse(data)
        return unless parsed["type"] == "confirm_subscription"

        Logger.debug "[EventStream] Subscription confirmed"
        @mutex.synchronize do
          @subscribed = true
          @subscribed_cv.signal
        end
      rescue JSON::ParserError
        nil
      rescue StandardError => e
        Logger.warn "[EventStream] Error handling message: #{e.message}"
      end

      def wait_for_subscription(timeout: 10)
        @mutex.synchronize do
          @subscribed_cv.wait(@mutex, timeout) unless @subscribed
        end
        Logger.warn "[EventStream] Subscription timed out" unless @subscribed
      end

      def cable_url
        base = ENV.fetch("WV_RUNNER_CABLE_URL").delete_suffix("/")
        token = ENV.fetch("WORKVECTOR_TOKEN", "")
        "#{base}?token=#{token}"
      end
    end
  end
end
