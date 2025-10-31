require "test_helper"

class DeciderTest < Minitest::Test
  def test_decider_responds_to_resolve
    decider = WvRunner::Decider.new
    assert_respond_to decider, :should_continue?
  end

  def test_should_continue_with_no_failures_and_time_remaining
    user_info = { "hour_goal" => 8 }
    task_results = [
      { "status" => "success", "hours" => { "task_worked" => 2.0 } }
    ]
    decider = WvRunner::Decider.new(user_info: user_info, task_results: task_results)

    assert decider.should_continue?
    assert !decider.should_stop?
  end

  def test_should_stop_when_daily_quota_exceeded
    user_info = { "hour_goal" => 8 }
    task_results = [
      { "status" => "success", "hours" => { "task_worked" => 5.0 } },
      { "status" => "success", "hours" => { "task_worked" => 4.0 } }
    ]
    decider = WvRunner::Decider.new(user_info: user_info, task_results: task_results)

    assert decider.should_stop?
    assert !decider.should_continue?
  end

  def test_should_stop_on_task_failure
    user_info = { "hour_goal" => 8 }
    task_results = [
      { "status" => "success", "hours" => { "task_worked" => 1.0 } },
      { "status" => "error", "message" => "Failed" }
    ]
    decider = WvRunner::Decider.new(user_info: user_info, task_results: task_results)

    assert decider.should_stop?
  end

  def test_remaining_hours_calculation
    user_info = { "hour_goal" => 8 }
    task_results = [
      { "status" => "success", "hours" => { "task_worked" => 3.5 } }
    ]
    decider = WvRunner::Decider.new(user_info: user_info, task_results: task_results)

    assert_equal 4.5, decider.remaining_hours
  end

  def test_remaining_hours_with_multiple_tasks
    user_info = { "hour_goal" => 8 }
    task_results = [
      { "status" => "success", "hours" => { "task_worked" => 2.0 } },
      { "status" => "success", "hours" => { "task_worked" => 1.5 } }
    ]
    decider = WvRunner::Decider.new(user_info: user_info, task_results: task_results)

    assert_equal 4.5, decider.remaining_hours
  end

  def test_remaining_hours_zero_with_no_user_info
    decider = WvRunner::Decider.new(user_info: nil, task_results: [])
    assert_equal 0, decider.remaining_hours
  end

  def test_summary_includes_all_info
    user_info = { "hour_goal" => 8 }
    task_results = [
      { "status" => "success", "hours" => { "task_worked" => 2.0 } }
    ]
    decider = WvRunner::Decider.new(user_info: user_info, task_results: task_results)

    summary = decider.summary

    assert summary.key?(:should_continue)
    assert summary.key?(:remaining_hours)
    assert summary.key?(:tasks_completed)
    assert summary.key?(:tasks_failed)

    assert_equal true, summary[:should_continue]
    assert_equal 6.0, summary[:remaining_hours]
    assert_equal 1, summary[:tasks_completed]
    assert_equal false, summary[:tasks_failed]
  end

  def test_accepts_single_task_result
    user_info = { "hour_goal" => 8 }
    task_result = { "status" => "success", "hours" => { "task_worked" => 1.0 } }
    decider = WvRunner::Decider.new(user_info: user_info, task_results: task_result)

    assert decider.should_continue?
    assert_equal 7.0, decider.remaining_hours
  end

  def test_handles_string_hour_values
    user_info = { "hour_goal" => "8" }
    task_results = [
      { "status" => "success", "hours" => { "task_worked" => "2.5" } }
    ]
    decider = WvRunner::Decider.new(user_info: user_info, task_results: task_results)

    assert_equal 5.5, decider.remaining_hours
  end
end
