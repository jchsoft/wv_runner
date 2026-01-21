# frozen_string_literal: true

require 'test_helper'

class WorkLoopTest < Minitest::Test
  def test_work_loop_responds_to_execute
    loop_instance = WvRunner::WorkLoop.new
    assert_respond_to loop_instance, :execute
  end

  def test_execute_with_once_calls_honest
    mock = Object.new
    def mock.run
      { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2, 'task_worked' => 0.5 } }
    end

    WvRunner::ClaudeCode::Honest.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      result = loop_instance.execute(:once)

      assert_equal 'success', result['status']
      assert_equal 8, result['hours']['per_day']
    end
  end

  def test_execute_with_once_handles_error
    mock = Object.new
    def mock.run
      { 'status' => 'error', 'message' => 'Task loading failed' }
    end

    WvRunner::ClaudeCode::Honest.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      result = loop_instance.execute(:once)

      assert_equal 'error', result['status']
      assert_equal 'Task loading failed', result['message']
    end
  end

  def test_execute_with_once_dry_calls_dry
    mock = Object.new
    def mock.run
      { 'status' => 'success', 'task_info' => { 'name' => 'Test Task', 'id' => 123 }, 'hours' => { 'per_day' => 8, 'task_estimated' => 1 } }
    end

    WvRunner::ClaudeCode::Dry.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      result = loop_instance.execute(:once_dry)

      assert_equal 'success', result['status']
      assert_equal 'Test Task', result['task_info']['name']
    end
  end

  def test_execute_raises_on_invalid_how
    loop_instance = WvRunner::WorkLoop.new
    assert_raises(ArgumentError) { loop_instance.execute(:invalid) }
  end

  def test_valid_how_values_constant
    assert_equal %i[once today daily once_dry review reviews workflow], WvRunner::WorkLoop::VALID_HOW_VALUES
  end

  def test_execute_validates_how_parameter
    loop_instance = WvRunner::WorkLoop.new

    error = assert_raises(ArgumentError) { loop_instance.execute(:unknown) }
    assert_includes error.message, "Invalid 'how' value"
    assert_includes error.message, 'once, today, daily, once_dry, review, reviews, workflow'
  end

  def test_execute_with_review_calls_review
    mock = Object.new
    def mock.run
      { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 0.5 } }
    end

    WvRunner::ClaudeCode::Review.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      result = loop_instance.execute(:review)

      assert_equal 'success', result['status']
      assert_equal 0.5, result['hours']['task_estimated']
    end
  end

  def test_execute_with_review_handles_no_reviews
    mock = Object.new
    def mock.run
      { 'status' => 'no_reviews', 'message' => 'No human reviews found to address' }
    end

    WvRunner::ClaudeCode::Review.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      result = loop_instance.execute(:review)

      assert_equal 'no_reviews', result['status']
    end
  end

  def test_execute_with_review_handles_not_on_branch
    mock = Object.new
    def mock.run
      { 'status' => 'not_on_branch', 'message' => 'Cannot review on main/master branch' }
    end

    WvRunner::ClaudeCode::Review.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      result = loop_instance.execute(:review)

      assert_equal 'not_on_branch', result['status']
    end
  end

  def test_execute_with_review_handles_no_pr
    mock = Object.new
    def mock.run
      { 'status' => 'no_pr', 'message' => 'No PR found for current branch' }
    end

    WvRunner::ClaudeCode::Review.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      result = loop_instance.execute(:review)

      assert_equal 'no_pr', result['status']
    end
  end

  def test_execute_with_reviews_loops_and_returns_array
    # Mock returns success first, then no_reviews to stop the loop
    call_count = [0]
    mock = Object.new
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 1.5 } } : { 'status' => 'no_reviews' }
    end

    WvRunner::ClaudeCode::Reviews.stub(:new, mock) do
      Kernel.stub(:sleep, nil) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:reviews)

        assert_instance_of Array, results
        assert_equal 2, results.length
        assert_equal 'success', results.first['status']
        assert_equal 'no_reviews', results.last['status']
      end
    end
  end

  def test_execute_with_reviews_stops_on_no_reviews
    mock = Object.new
    def mock.run
      { 'status' => 'no_reviews', 'message' => 'No PRs with human reviews found' }
    end

    WvRunner::ClaudeCode::Reviews.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      results = loop_instance.execute(:reviews)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'no_reviews', results.first['status']
    end
  end

  def test_execute_with_reviews_stops_on_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Error processing reviews' }
    end

    WvRunner::ClaudeCode::Reviews.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      results = loop_instance.execute(:reviews)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'failure', results.first['status']
    end
  end

  def test_verbose_mode_can_be_enabled
    loop_instance = WvRunner::WorkLoop.new(verbose: true)
    assert_instance_of WvRunner::WorkLoop, loop_instance
  end

  # Tests for no_more_tasks handling
  def test_no_tasks_available_detects_no_more_tasks_status
    loop_instance = WvRunner::WorkLoop.new
    result = { 'status' => 'no_more_tasks' }

    assert loop_instance.send(:no_tasks_available?, result)
  end

  def test_no_tasks_available_returns_false_for_success
    loop_instance = WvRunner::WorkLoop.new
    result = { 'status' => 'success' }

    refute loop_instance.send(:no_tasks_available?, result)
  end

  def test_no_tasks_available_returns_false_for_error
    loop_instance = WvRunner::WorkLoop.new
    result = { 'status' => 'error', 'message' => 'Some error' }

    refute loop_instance.send(:no_tasks_available?, result)
  end

  def test_run_today_exits_immediately_on_no_more_tasks
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    WvRunner::ClaudeCode::Honest.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      results = loop_instance.execute(:today)

      assert_equal 1, results.length
      assert_equal 'no_more_tasks', results.first['status']
    end
  end

  def test_end_of_workday_returns_true_after_18
    loop_instance = WvRunner::WorkLoop.new

    Time.stub(:now, Time.new(2025, 1, 15, 18, 30)) do
      assert loop_instance.send(:end_of_workday?)
    end
  end

  def test_end_of_workday_returns_false_before_18
    loop_instance = WvRunner::WorkLoop.new

    Time.stub(:now, Time.new(2025, 1, 15, 14, 30)) do
      refute loop_instance.send(:end_of_workday?)
    end
  end

  def test_handle_no_tasks_in_daily_mode_returns_false_after_workday
    loop_instance = WvRunner::WorkLoop.new

    Time.stub(:now, Time.new(2025, 1, 15, 19, 0)) do
      refute loop_instance.send(:handle_no_tasks_in_daily_mode)
    end
  end

  # Tests for workflow mode
  def test_execute_with_workflow_returns_hash_with_reviews_and_tasks
    reviews_mock = Object.new
    def reviews_mock.run
      { 'status' => 'no_reviews' }
    end

    honest_mock = Object.new
    def honest_mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    WvRunner::ClaudeCode::Reviews.stub(:new, reviews_mock) do
      WvRunner::ClaudeCode::Honest.stub(:new, honest_mock) do
        loop_instance = WvRunner::WorkLoop.new
        result = loop_instance.execute(:workflow)

        assert_instance_of Hash, result
        assert result.key?('reviews')
        assert result.key?('tasks')
        assert_instance_of Array, result['reviews']
        assert_instance_of Array, result['tasks']
      end
    end
  end

  def test_execute_with_workflow_processes_reviews_first
    reviews_call_order = []

    reviews_mock = Object.new
    reviews_mock.define_singleton_method(:run) do
      reviews_call_order << :reviews
      { 'status' => 'no_reviews' }
    end

    honest_mock = Object.new
    honest_mock.define_singleton_method(:run) do
      reviews_call_order << :honest
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    WvRunner::ClaudeCode::Reviews.stub(:new, reviews_mock) do
      WvRunner::ClaudeCode::Honest.stub(:new, honest_mock) do
        loop_instance = WvRunner::WorkLoop.new
        loop_instance.execute(:workflow)

        # Reviews should be called before Honest (tasks)
        assert_equal :reviews, reviews_call_order.first
      end
    end
  end

  def test_execute_with_workflow_collects_review_results
    reviews_mock = Object.new
    call_count = [0]
    reviews_mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'pr' => 'PR #1' } : { 'status' => 'no_reviews' }
    end

    honest_mock = Object.new
    def honest_mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    WvRunner::ClaudeCode::Reviews.stub(:new, reviews_mock) do
      WvRunner::ClaudeCode::Honest.stub(:new, honest_mock) do
        Kernel.stub(:sleep, nil) do
          loop_instance = WvRunner::WorkLoop.new
          result = loop_instance.execute(:workflow)

          assert_equal 2, result['reviews'].length
          assert_equal 'success', result['reviews'].first['status']
          assert_equal 'no_reviews', result['reviews'].last['status']
        end
      end
    end
  end

  def test_execute_with_workflow_collects_task_results
    reviews_mock = Object.new
    def reviews_mock.run
      { 'status' => 'no_reviews' }
    end

    honest_mock = Object.new
    def honest_mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    WvRunner::ClaudeCode::Reviews.stub(:new, reviews_mock) do
      WvRunner::ClaudeCode::Honest.stub(:new, honest_mock) do
        loop_instance = WvRunner::WorkLoop.new
        result = loop_instance.execute(:workflow)

        assert_equal 1, result['tasks'].length
        assert_equal 'no_more_tasks', result['tasks'].first['status']
      end
    end
  end
end
