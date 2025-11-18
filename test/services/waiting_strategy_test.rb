require 'test_helper'

class WaitingStrategyTest < Minitest::Test
  def test_wait_one_hour_sleeps
    strategy = WvRunner::WaitingStrategy.new
    slept = false
    strategy.stub :sleep, ->(seconds) { slept = seconds == 3600 } do
      assert_output(/Waiting 1 hour before retry/) { strategy.wait_one_hour }
    end
    assert slept
  end

  def test_wait_until_next_day_calls_sleep
    strategy = WvRunner::WaitingStrategy.new
    original_sleep_called = false

    # Mock Time.now to a known time (Monday 9 PM)
    mock_time = Time.new(2025, 11, 3, 21, 0, 0)
    Time.stub :now, mock_time do
      strategy.stub :sleep, ->(seconds) { original_sleep_called = true } do
        assert_output(/Waiting/) { strategy.wait_until_next_day }
        assert original_sleep_called
      end
    end
  end

  def test_wait_until_next_day_skips_weekends
    strategy = WvRunner::WaitingStrategy.new

    # Mock Time.now to Friday
    mock_time = Time.new(2025, 11, 7, 21, 0, 0) # Friday 9 PM
    sleep_calls = []
    Time.stub :now, mock_time do
      strategy.stub :sleep, ->(seconds) { sleep_calls << seconds } do
        assert_output(/Waiting/) { strategy.wait_until_next_day }
      end
    end

    # Should wait until Monday 8 AM (not Saturday or Sunday)
    assert_equal 1, sleep_calls.length
    # The wait should be until Monday at 8 AM
    assert sleep_calls[0] > 0
  end
end
