# frozen_string_literal: true

require "test_helper"

class EventStreamTest < Minitest::Test
  def setup
    McptaskRunner::EventStream.instance_variable_set(:@ws, nil)
    McptaskRunner::EventStream.instance_variable_set(:@subscribed, false)
  end

  def test_disabled_when_cable_url_not_set
    with_env("WV_RUNNER_CABLE_URL" => nil) do
      refute McptaskRunner::EventStream.enabled?
    end
  end

  def test_enabled_when_cable_url_set
    with_env("WV_RUNNER_CABLE_URL" => "ws://localhost:3000/cable") do
      assert McptaskRunner::EventStream.enabled?
    end
  end

  def test_disabled_when_cable_url_empty
    with_env("WV_RUNNER_CABLE_URL" => "") do
      refute McptaskRunner::EventStream.enabled?
    end
  end

  def test_start_session_noop_when_disabled
    with_env("WV_RUNNER_CABLE_URL" => nil) do
      # Should not raise, should not attempt connection
      McptaskRunner::EventStream.start_session(mode: :honest)
    end
  end

  def test_emit_noop_when_disabled
    with_env("WV_RUNNER_CABLE_URL" => nil) do
      McptaskRunner::EventStream.emit("session.started", { session_id: "123" })
    end
  end

  def test_end_session_noop_when_disabled
    with_env("WV_RUNNER_CABLE_URL" => nil) do
      McptaskRunner::EventStream.end_session
    end
  end

  def test_emit_noop_when_ws_not_connected
    with_env("WV_RUNNER_CABLE_URL" => "ws://localhost:3000/cable") do
      McptaskRunner::EventStream.instance_variable_set(:@ws, nil)
      # Should not raise
      McptaskRunner::EventStream.emit("session.started", { session_id: "123" })
    end
  end

  def test_channel_identifier_is_valid_json
    parsed = JSON.parse(McptaskRunner::EventStream::CHANNEL_IDENTIFIER)
    assert_equal "RunnerSessionChannel", parsed["channel"]
  end

  private

  def with_env(vars)
    original = vars.keys.map { |k| [ k, ENV[k] ] }.to_h
    vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
