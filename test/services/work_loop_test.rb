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
      assert_output(/\[WorkLoop\] \[execute\] Starting execution with mode: :once/) { loop.execute(:once) }
      mock.verify
    end
  end

  def test_execute_with_once_dry
    mock_result = { "status" => "success", "task_info" => { "name" => "Test Task", "id" => 123, "description" => "Do something", "status" => "New", "priority" => "High", "assigned_user" => "John Doe", "scrum_points" => "M" }, "hours" => { "per_day" => 8, "task_estimated" => 0 } }
    mock = Minitest::Mock.new
    mock.expect(:run_dry, mock_result)
    WvRunner::ClaudeCode.stub :new, mock do
      loop = WvRunner::WorkLoop.new
      result = loop.execute(:once_dry)
      assert_equal "success", result["status"]
      assert result["task_info"].key?("name")
      assert_equal "Test Task", result["task_info"]["name"]
      mock.verify
    end
  end

  def test_run_today_uses_decider
    mock_result = { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 0.5 } }
    mock = Minitest::Mock.new
    mock.expect(:run, mock_result)
    WvRunner::ClaudeCode.stub :new, mock do
      loop = WvRunner::WorkLoop.new
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
      def loop.end_of_day?
        false
      end
      result = loop.execute(:today)
      assert result.is_a?(Array)
      assert_equal 1, result.length
      assert_equal "error", result.first["status"]
    end
  end

  def test_run_daily_stops_on_decider_should_stop
    # When accumulated hours exceed daily limit, Decider says stop
    mock_result = { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 8.5 } }
    mock = Minitest::Mock.new
    mock.expect(:run, mock_result)
    WvRunner::ClaudeCode.stub :new, mock do
      # Mock WaitingStrategy to prevent actual sleeping
      waiting_mock = Minitest::Mock.new
      waiting_mock.expect(:wait_until_next_day, nil)
      WvRunner::WaitingStrategy.stub :new, waiting_mock do
        loop = WvRunner::WorkLoop.new
        # run_daily is infinite loop, we need to intercept after first iteration
        def loop.run_daily
          wait_if_cannot_work_today
          daily_results = run_today_tasks
          handle_daily_completion(daily_results)
          daily_results # Return results instead of looping
        end
        result = loop.execute(:daily)

        assert result.is_a?(Array)
        assert_equal 1, result.length
        # Should stop because 8.5 > 8 (daily limit exceeded)
      end
    end
  end

  def test_execute_raises_on_invalid_how
    loop = WvRunner::WorkLoop.new
    assert_raises(ArgumentError) { loop.execute(:invalid) }
  end

  def test_send_dispatches_to_correct_method
    loop = WvRunner::WorkLoop.new
    mock_result = { "status" => "success" }
    mock = Minitest::Mock.new
    mock.expect(:run, mock_result)
    WvRunner::ClaudeCode.stub :new, mock do
      assert_output(/\[WorkLoop\] \[execute\] Starting execution with mode: :once/) { loop.execute(:once) }
    end
  end

  def test_results_accumulation
    mock_result = { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 0.5 } }
    mock = Minitest::Mock.new
    mock.expect(:run, mock_result)
    WvRunner::ClaudeCode.stub :new, mock do
      loop = WvRunner::WorkLoop.new
      def loop.end_of_day?
        true
      end
      result = loop.execute(:today)

      assert result.is_a?(Array)
      assert_equal 1, result.length
      assert_equal "success", result.first["status"]
    end
  end
end
