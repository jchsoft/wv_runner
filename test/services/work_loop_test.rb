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

  def test_execute_with_today_exits_at_end_of_day
    mock_result = { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 0.5 } }
    mock = Minitest::Mock.new
    mock.expect(:run, mock_result)
    WvRunner::ClaudeCode.stub :new, mock do
      loop = WvRunner::WorkLoop.new
      # Stub end_of_day? to return true immediately to prevent infinite loop
      def loop.end_of_day?
        true
      end
      assert_output(/Running task iteration/) { loop.execute(:today) }
    end
  end

  def test_execute_with_today_exits_on_error
    error_result = { "status" => "error", "message" => "Something went wrong" }
    mock = Minitest::Mock.new
    mock.expect(:run, error_result)
    WvRunner::ClaudeCode.stub :new, mock do
      loop = WvRunner::WorkLoop.new
      # Stub end_of_day? to return false so should_stop? logic is tested
      def loop.end_of_day?
        false
      end
      assert_output(/Task result.*error/) { loop.execute(:today) }
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
end
