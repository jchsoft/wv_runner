require 'test_helper'

class DailySchedulerTest < Minitest::Test
  def test_can_work_today_returns_true_when_quota_present
    result = { 'hours' => { 'per_day' => 8, 'task_worked' => 0 }, 'status' => 'success' }
    scheduler = WvRunner::DailyScheduler.new(task_results: result)
    assert scheduler.can_work_today?
  end

  def test_can_work_today_returns_false_when_quota_zero
    result = { 'hours' => { 'per_day' => 0, 'task_worked' => 0 }, 'status' => 'success' }
    scheduler = WvRunner::DailyScheduler.new(task_results: result)
    refute scheduler.can_work_today?
  end

  def test_can_work_today_returns_true_with_empty_results
    scheduler = WvRunner::DailyScheduler.new(task_results: [])
    assert scheduler.can_work_today?
  end

  def test_should_continue_working_when_quota_not_exceeded
    result = { 'hours' => { 'per_day' => 8, 'task_worked' => 2 }, 'status' => 'success' }
    scheduler = WvRunner::DailyScheduler.new(task_results: result)
    assert scheduler.should_continue_working?
  end

  def test_should_continue_working_returns_false_when_quota_exceeded
    result = { 'hours' => { 'per_day' => 8, 'task_worked' => 8.5 }, 'status' => 'success' }
    scheduler = WvRunner::DailyScheduler.new(task_results: result)
    refute scheduler.should_continue_working?
  end

  def test_should_continue_working_with_multiple_results
    results = [
      { 'hours' => { 'per_day' => 8, 'task_worked' => 3 }, 'status' => 'success' },
      { 'hours' => { 'per_day' => 8, 'task_worked' => 4 }, 'status' => 'success' }
    ]
    scheduler = WvRunner::DailyScheduler.new(task_results: results)
    assert scheduler.should_continue_working? # 3 + 4 = 7 hours, under 8
  end

  def test_should_continue_working_false_with_multiple_results_exceeding_quota
    results = [
      { 'hours' => { 'per_day' => 8, 'task_worked' => 5 }, 'status' => 'success' },
      { 'hours' => { 'per_day' => 8, 'task_worked' => 4 }, 'status' => 'success' }
    ]
    scheduler = WvRunner::DailyScheduler.new(task_results: results)
    refute scheduler.should_continue_working? # 5 + 4 = 9 hours, over 8
  end

  def test_wait_reason_returns_zero_quota
    result = { 'hours' => { 'per_day' => 0, 'task_worked' => 0 }, 'status' => 'success' }
    scheduler = WvRunner::DailyScheduler.new(task_results: result)
    assert_equal :zero_quota, scheduler.wait_reason
  end

  def test_wait_reason_returns_quota_exceeded
    result = { 'hours' => { 'per_day' => 8, 'task_worked' => 8.5 }, 'status' => 'success' }
    scheduler = WvRunner::DailyScheduler.new(task_results: result)
    assert_equal :quota_exceeded, scheduler.wait_reason
  end

  def test_wait_reason_returns_nil_when_can_continue
    result = { 'hours' => { 'per_day' => 8, 'task_worked' => 2 }, 'status' => 'success' }
    scheduler = WvRunner::DailyScheduler.new(task_results: result)
    assert_nil scheduler.wait_reason
  end
end
