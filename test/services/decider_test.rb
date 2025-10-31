require "test_helper"

class DeciderTest < Minitest::Test
  def test_decider_responds_to_should_continue
    decider = WvRunner::Decider.new
    assert_respond_to decider, :should_continue?
  end

  def test_should_continue_with_time_remaining
    task_result = {
      "status" => "success",
      "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 0.5 }
    }
    decider = WvRunner::Decider.new(task_results: [task_result])

    assert decider.should_continue?
    assert !decider.should_stop?
  end

  def test_should_stop_when_daily_quota_exceeded
    # 8 hour day, already worked 5.5 + 3 = 8.5 hours
    results = [
      { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 5.5 } },
      { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 3.0 } }
    ]
    decider = WvRunner::Decider.new(task_results: results)

    assert decider.should_stop?
    assert !decider.should_continue?
  end

  def test_should_stop_on_task_failure
    results = [
      { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 1.0 } },
      { "status" => "error", "message" => "Failed" }
    ]
    decider = WvRunner::Decider.new(task_results: results)

    assert decider.should_stop?
  end

  def test_remaining_hours_calculation
    task_result = {
      "status" => "success",
      "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 3.5 }
    }
    decider = WvRunner::Decider.new(task_results: [task_result])

    assert_equal 4.5, decider.remaining_hours
  end

  def test_remaining_hours_with_multiple_accumulated_tasks
    # 8 hour day, worked 2 + 1.5 = 3.5 hours
    results = [
      { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 2.0 } },
      { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 1, "task_worked" => 1.5 } }
    ]
    decider = WvRunner::Decider.new(task_results: results)

    assert_equal 4.5, decider.remaining_hours
  end

  def test_remaining_hours_exactly_zero
    results = [
      { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 8.0 } }
    ]
    decider = WvRunner::Decider.new(task_results: results)

    assert_equal 0, decider.remaining_hours
  end

  def test_summary_includes_all_info
    results = [
      { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 2.0 } }
    ]
    decider = WvRunner::Decider.new(task_results: results)

    summary = decider.summary

    assert summary.key?(:should_continue)
    assert summary.key?(:remaining_hours)
    assert summary.key?(:tasks_completed)
    assert summary.key?(:tasks_failed)
    assert summary.key?(:daily_limit)
    assert summary.key?(:total_worked)

    assert_equal true, summary[:should_continue]
    assert_equal 6.0, summary[:remaining_hours]
    assert_equal 1, summary[:tasks_completed]
    assert_equal false, summary[:tasks_failed]
    assert_equal 8.0, summary[:daily_limit]
    assert_equal 2.0, summary[:total_worked]
  end

  def test_accepts_single_task_result
    task_result = {
      "status" => "success",
      "hours" => { "per_day" => 8, "task_estimated" => 1, "task_worked" => 1.0 }
    }
    decider = WvRunner::Decider.new(task_results: task_result)

    assert decider.should_continue?
    assert_equal 7.0, decider.remaining_hours
  end

  def test_handles_string_hour_values
    results = [
      { "status" => "success", "hours" => { "per_day" => "8", "task_estimated" => "2", "task_worked" => "2.5" } }
    ]
    decider = WvRunner::Decider.new(task_results: results)

    assert_equal 5.5, decider.remaining_hours
  end

  def test_empty_results_returns_zero_hours
    decider = WvRunner::Decider.new(task_results: [])

    assert_equal 0, decider.remaining_hours
    assert_equal 0, decider.send(:daily_hour_goal)
    assert_equal 0, decider.send(:total_hours_worked)
  end

  def test_daily_hour_goal_from_first_result
    results = [
      { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 1.0 } },
      { "status" => "success", "hours" => { "per_day" => 10, "task_estimated" => 1, "task_worked" => 0.5 } }
    ]
    decider = WvRunner::Decider.new(task_results: results)

    # Should use per_day from FIRST result (8, not 10)
    assert_equal 8.0, decider.send(:daily_hour_goal)
  end

  def test_total_hours_worked_sums_all_results
    results = [
      { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 1.0 } },
      { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 1, "task_worked" => 1.5 } },
      { "status" => "success", "hours" => { "per_day" => 8, "task_estimated" => 2, "task_worked" => 2.25 } }
    ]
    decider = WvRunner::Decider.new(task_results: results)

    assert_equal 4.75, decider.send(:total_hours_worked)
  end
end
