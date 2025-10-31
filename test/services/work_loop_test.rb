require "test_helper"

class WorkLoopTest < Minitest::Test
  def test_work_loop_responds_to_execute
    loop = WvRunner::WorkLoop.new
    assert_respond_to loop, :execute
  end

  def test_execute_with_once
    mock_result = { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 0.5 } }
    mock = Minitest::Mock.new
    mock.expect(:run, mock_result)
    WvRunner::ClaudeCode.stub :new, mock do
      loop = WvRunner::WorkLoop.new
      assert_output(/WorkLoop executing with mode: once/) { loop.execute(:once) }
      mock.verify
    end
  end

  def test_run_today_uses_decider
    mock_result = { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 0.5 } }
    mock = Minitest::Mock.new
    mock.expect(:run, mock_result)
    WvRunner::ClaudeCode.stub :new, mock do
      loop = WvRunner::WorkLoop.new
      # Stub end_of_day? to return true immediately to prevent infinite loop
      def loop.end_of_day?
        true
      end
      result = loop.execute(:today)
      assert result.is_a?(Array)
      assert_equal 1, result.length
    end
  end

  def test_run_today_stops_on_error
    error_result = { "status" => "error", "message" => "Something went wrong" }
    mock = Minitest::Mock.new
    mock.expect(:run, error_result)
    WvRunner::ClaudeCode.stub :new, mock do
      loop = WvRunner::WorkLoop.new
      # Stub end_of_day? to return false so Decider logic is tested
      def loop.end_of_day?
        false
      end
      result = loop.execute(:today)
      assert result.is_a?(Array)
      assert_equal 1, result.length
      assert_equal "error", result.first["status"]
    end
  end

  def test_run_daily_loops_with_decider
    mock_result = { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 1.0 } }
    error_result = { "status" => "error", "message" => "Failed" }

    call_count = 0
    mock = Minitest::Mock.new
    mock.expect(:run, mock_result)
    mock.expect(:run, error_result)

    WvRunner::ClaudeCode.stub :new, mock do
      loop = WvRunner::WorkLoop.new
      result = loop.execute(:daily)

      assert result.is_a?(Array)
      assert_equal 2, result.length
      assert_equal "success", result.first["status"]
      assert_equal "error", result.last["status"]
    end
  end

  def test_execute_raises_on_invalid_how
    loop = WvRunner::WorkLoop.new
    assert_raises(ArgumentError) { loop.execute(:invalid) }
  end

  def test_send_dispatches_to_correct_method
    loop = WvRunner::WorkLoop.new
    # Verify that send is dispatching to the right method
    mock_result = { "status" => "success" }
    mock = Minitest::Mock.new
    mock.expect(:run, mock_result)
    WvRunner::ClaudeCode.stub :new, mock do
      # This should call run_once via send
      assert_output(/WorkLoop executing with mode: once/) { loop.execute(:once) }
    end
  end

  def test_load_user_info_returns_nil
    loop = WvRunner::WorkLoop.new
    user_info = loop.send(:load_user_info)
    assert_nil user_info
  end

  def test_decider_receives_accumulated_results
    # Test that WorkLoop accumulates results in an array
    mock_result = { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 0.5 } }
    mock = Minitest::Mock.new
    mock.expect(:run, mock_result)

    WvRunner::ClaudeCode.stub :new, mock do
      loop = WvRunner::WorkLoop.new
      def loop.end_of_day?
        true  # Exit immediately after first result
      end
      result = loop.execute(:today)

      # Verify results are returned as array
      assert result.is_a?(Array)
      assert_equal 1, result.length
      assert_equal "success", result.first["status"]
    end
  end
end
