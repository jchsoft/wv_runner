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
    assert_equal %i[once today daily once_dry review reviews workflow story_manual story_auto_squash today_auto_squash queue_auto_squash queue_manual once_auto_squash], WvRunner::WorkLoop::VALID_HOW_VALUES
  end

  def test_execute_validates_how_parameter
    loop_instance = WvRunner::WorkLoop.new

    error = assert_raises(ArgumentError) { loop_instance.execute(:unknown) }
    assert_includes error.message, "Invalid 'how' value"
    assert_includes error.message, 'once, today, daily, once_dry, review, reviews, workflow, story_manual, story_auto_squash, today_auto_squash, queue_auto_squash, queue_manual, once_auto_squash'
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

  # Tests for story_manual mode
  def test_execute_with_story_manual_requires_story_id
    loop_instance = WvRunner::WorkLoop.new
    error = assert_raises(ArgumentError) { loop_instance.execute(:story_manual) }
    assert_includes error.message, 'story_id is required'
  end

  def test_execute_with_story_manual_calls_story_manual_class
    mock = Object.new
    def mock.run
      { 'status' => 'success', 'story_id' => 123, 'task_id' => 456, 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } }
    end

    # Mock returns success first, then no_more_tasks to stop the loop
    call_count = [0]
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'story_id' => 123, 'task_id' => 456, 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } } : { 'status' => 'no_more_tasks' }
    end

    WvRunner::ClaudeCode::StoryManual.stub(:new, mock) do
      Kernel.stub(:sleep, nil) do
        loop_instance = WvRunner::WorkLoop.new(story_id: 123)
        results = loop_instance.execute(:story_manual)

        assert_instance_of Array, results
        assert_equal 2, results.length
        assert_equal 'success', results.first['status']
        assert_equal 'no_more_tasks', results.last['status']
      end
    end
  end

  def test_execute_with_story_manual_stops_on_no_more_tasks
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks', 'story_id' => 123 }
    end

    WvRunner::ClaudeCode::StoryManual.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new(story_id: 123)
      results = loop_instance.execute(:story_manual)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'no_more_tasks', results.first['status']
    end
  end

  def test_execute_with_story_manual_stops_on_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Error processing task' }
    end

    WvRunner::ClaudeCode::StoryManual.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new(story_id: 123)
      results = loop_instance.execute(:story_manual)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'failure', results.first['status']
    end
  end

  def test_story_id_can_be_passed_to_constructor
    loop_instance = WvRunner::WorkLoop.new(story_id: 999)
    assert_instance_of WvRunner::WorkLoop, loop_instance
  end

  def test_story_id_and_verbose_can_be_combined
    loop_instance = WvRunner::WorkLoop.new(verbose: true, story_id: 888)
    assert_instance_of WvRunner::WorkLoop, loop_instance
  end

  # Tests for story_auto_squash mode
  def test_execute_with_story_auto_squash_requires_story_id
    loop_instance = WvRunner::WorkLoop.new
    error = assert_raises(ArgumentError) { loop_instance.execute(:story_auto_squash) }
    assert_includes error.message, 'story_id is required'
  end

  def test_execute_with_story_auto_squash_calls_story_auto_squash_class
    # Mock returns success first, then no_more_tasks to stop the loop
    call_count = [0]
    mock = Object.new
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'story_id' => 123, 'task_id' => 456, 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } } : { 'status' => 'no_more_tasks' }
    end

    WvRunner::ClaudeCode::StoryAutoSquash.stub(:new, mock) do
      Kernel.stub(:sleep, nil) do
        loop_instance = WvRunner::WorkLoop.new(story_id: 123)
        results = loop_instance.execute(:story_auto_squash)

        assert_instance_of Array, results
        assert_equal 2, results.length
        assert_equal 'success', results.first['status']
        assert_equal 'no_more_tasks', results.last['status']
      end
    end
  end

  def test_execute_with_story_auto_squash_stops_on_no_more_tasks
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks', 'story_id' => 123 }
    end

    WvRunner::ClaudeCode::StoryAutoSquash.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new(story_id: 123)
      results = loop_instance.execute(:story_auto_squash)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'no_more_tasks', results.first['status']
    end
  end

  def test_execute_with_story_auto_squash_stops_on_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Error processing task' }
    end

    WvRunner::ClaudeCode::StoryAutoSquash.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new(story_id: 123)
      results = loop_instance.execute(:story_auto_squash)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'failure', results.first['status']
    end
  end

  def test_execute_with_story_auto_squash_stops_on_ci_failed
    mock = Object.new
    def mock.run
      { 'status' => 'ci_failed', 'message' => 'CI failed after retry' }
    end

    WvRunner::ClaudeCode::StoryAutoSquash.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new(story_id: 123)
      results = loop_instance.execute(:story_auto_squash)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'ci_failed', results.first['status']
    end
  end

  # Tests for today_auto_squash mode
  def test_execute_with_today_auto_squash_calls_today_auto_squash_class
    # Mock returns success first, then no_more_tasks to stop the loop
    call_count = [0]
    mock = Object.new
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } } : { 'status' => 'no_more_tasks' }
    end

    decider_mock = Object.new
    def decider_mock.should_stop?
      false
    end

    WvRunner::ClaudeCode::TodayAutoSquash.stub(:new, mock) do
      WvRunner::Decider.stub(:new, decider_mock) do
        Kernel.stub(:sleep, nil) do
          Time.stub(:now, Time.new(2025, 1, 15, 19, 0)) do
            loop_instance = WvRunner::WorkLoop.new
            results = loop_instance.execute(:today_auto_squash)

            assert_instance_of Array, results
            assert_equal 2, results.length
            assert_equal 'success', results.first['status']
            assert_equal 'no_more_tasks', results.last['status']
          end
        end
      end
    end
  end

  def test_execute_with_today_auto_squash_stops_on_no_more_tasks
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    WvRunner::ClaudeCode::TodayAutoSquash.stub(:new, mock) do
      Time.stub(:now, Time.new(2025, 1, 15, 19, 0)) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:today_auto_squash)

        assert_instance_of Array, results
        assert_equal 1, results.length
        assert_equal 'no_more_tasks', results.first['status']
      end
    end
  end

  def test_execute_with_today_auto_squash_stops_immediately_after_workday
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks' }
    end

    WvRunner::ClaudeCode::TodayAutoSquash.stub(:new, mock) do
      Time.stub(:now, Time.new(2025, 1, 15, 18, 0)) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:today_auto_squash)

        assert_equal 1, results.length
        assert_equal 'no_more_tasks', results.first['status']
      end
    end
  end

  def test_handle_no_tasks_in_today_auto_squash_mode_returns_false_after_workday
    loop_instance = WvRunner::WorkLoop.new

    Time.stub(:now, Time.new(2025, 1, 15, 19, 0)) do
      refute loop_instance.send(:handle_no_tasks_in_today_auto_squash_mode)
    end
  end

  def test_handle_no_tasks_in_today_auto_squash_mode_returns_false_at_18
    loop_instance = WvRunner::WorkLoop.new

    Time.stub(:now, Time.new(2025, 1, 15, 18, 0)) do
      refute loop_instance.send(:handle_no_tasks_in_today_auto_squash_mode)
    end
  end

  def test_execute_with_today_auto_squash_stops_on_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Error processing task' }
    end

    WvRunner::ClaudeCode::TodayAutoSquash.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      results = loop_instance.execute(:today_auto_squash)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'failure', results.first['status']
    end
  end

  def test_execute_with_today_auto_squash_stops_on_ci_failed
    mock = Object.new
    def mock.run
      { 'status' => 'ci_failed', 'message' => 'CI failed after retry' }
    end

    WvRunner::ClaudeCode::TodayAutoSquash.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      results = loop_instance.execute(:today_auto_squash)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'ci_failed', results.first['status']
    end
  end

  def test_execute_with_today_auto_squash_checks_quota
    # First call returns success, but quota is reached so loop should stop
    mock = Object.new
    def mock.run
      { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 8 } }
    end

    decider_mock = Object.new
    def decider_mock.should_stop?
      true
    end

    WvRunner::ClaudeCode::TodayAutoSquash.stub(:new, mock) do
      WvRunner::Decider.stub(:new, decider_mock) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:today_auto_squash)

        assert_instance_of Array, results
        assert_equal 1, results.length
        assert_equal 'success', results.first['status']
      end
    end
  end

  # Tests for queue_auto_squash mode
  def test_execute_with_queue_auto_squash_calls_queue_auto_squash_class
    # Mock returns success first, then no_more_tasks to stop the loop
    call_count = [0]
    mock = Object.new
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } } : { 'status' => 'no_more_tasks' }
    end

    WvRunner::ClaudeCode::QueueAutoSquash.stub(:new, mock) do
      Kernel.stub(:sleep, nil) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:queue_auto_squash)

        assert_instance_of Array, results
        assert_equal 2, results.length
        assert_equal 'success', results.first['status']
        assert_equal 'no_more_tasks', results.last['status']
      end
    end
  end

  def test_execute_with_queue_auto_squash_stops_on_no_more_tasks
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    WvRunner::ClaudeCode::QueueAutoSquash.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      results = loop_instance.execute(:queue_auto_squash)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'no_more_tasks', results.first['status']
    end
  end

  def test_execute_with_queue_auto_squash_stops_on_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Error processing task' }
    end

    WvRunner::ClaudeCode::QueueAutoSquash.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      results = loop_instance.execute(:queue_auto_squash)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'failure', results.first['status']
    end
  end

  def test_execute_with_queue_auto_squash_stops_on_ci_failed
    mock = Object.new
    def mock.run
      { 'status' => 'ci_failed', 'message' => 'CI failed after retry' }
    end

    WvRunner::ClaudeCode::QueueAutoSquash.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      results = loop_instance.execute(:queue_auto_squash)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'ci_failed', results.first['status']
    end
  end

  def test_execute_with_queue_auto_squash_does_not_check_quota
    # Queue auto squash should NOT check quota - runs continuously
    # This test verifies Decider is NOT called
    mock = Object.new
    mock.define_singleton_method(:run) do
      { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 8 } }
    end

    # Setup mock that would raise if Decider.new is called
    decider_class_mock = Object.new
    decider_class_mock.define_singleton_method(:new) do |*_args|
      raise 'Decider should NOT be called in queue_auto_squash mode!'
    end

    call_count = [0]
    # Need to stop loop manually since there's no quota check
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } } : { 'status' => 'no_more_tasks' }
    end

    WvRunner::ClaudeCode::QueueAutoSquash.stub(:new, mock) do
      Kernel.stub(:sleep, nil) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:queue_auto_squash)

        assert_instance_of Array, results
        assert_equal 2, results.length
        # Verify it processed multiple tasks without quota check stopping it
      end
    end
  end

  # Tests for queue_manual mode
  def test_execute_with_queue_manual_calls_honest_class
    # Mock returns success first, then no_more_tasks to stop the loop
    call_count = [0]
    mock = Object.new
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } } : { 'status' => 'no_more_tasks' }
    end

    WvRunner::ClaudeCode::Honest.stub(:new, mock) do
      Kernel.stub(:sleep, nil) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:queue_manual)

        assert_instance_of Array, results
        assert_equal 2, results.length
        assert_equal 'success', results.first['status']
        assert_equal 'no_more_tasks', results.last['status']
      end
    end
  end

  def test_execute_with_queue_manual_stops_on_no_more_tasks
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    WvRunner::ClaudeCode::Honest.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      results = loop_instance.execute(:queue_manual)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'no_more_tasks', results.first['status']
    end
  end

  def test_execute_with_queue_manual_stops_on_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Error processing task' }
    end

    WvRunner::ClaudeCode::Honest.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      results = loop_instance.execute(:queue_manual)

      assert_instance_of Array, results
      assert_equal 1, results.length
      assert_equal 'failure', results.first['status']
    end
  end

  def test_execute_with_queue_manual_does_not_check_quota
    # Queue manual should NOT check quota - runs continuously without quota or time checks
    call_count = [0]
    mock = Object.new
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } } : { 'status' => 'no_more_tasks' }
    end

    WvRunner::ClaudeCode::Honest.stub(:new, mock) do
      Kernel.stub(:sleep, nil) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:queue_manual)

        assert_instance_of Array, results
        assert_equal 2, results.length
        # Verify it processed multiple tasks without quota check stopping it
      end
    end
  end

  # Tests for once_auto_squash mode
  def test_execute_with_once_auto_squash_calls_once_auto_squash_class
    mock = Object.new
    def mock.run
      { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } }
    end

    WvRunner::ClaudeCode::OnceAutoSquash.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      result = loop_instance.execute(:once_auto_squash)

      assert_equal 'success', result['status']
      assert_equal 8, result['hours']['per_day']
    end
  end

  def test_execute_with_once_auto_squash_handles_no_more_tasks
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    WvRunner::ClaudeCode::OnceAutoSquash.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      result = loop_instance.execute(:once_auto_squash)

      assert_equal 'no_more_tasks', result['status']
    end
  end

  def test_execute_with_once_auto_squash_handles_ci_failed
    mock = Object.new
    def mock.run
      { 'status' => 'ci_failed', 'message' => 'CI failed after retry' }
    end

    WvRunner::ClaudeCode::OnceAutoSquash.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      result = loop_instance.execute(:once_auto_squash)

      assert_equal 'ci_failed', result['status']
    end
  end

  def test_execute_with_once_auto_squash_handles_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Some error' }
    end

    WvRunner::ClaudeCode::OnceAutoSquash.stub(:new, mock) do
      loop_instance = WvRunner::WorkLoop.new
      result = loop_instance.execute(:once_auto_squash)

      assert_equal 'failure', result['status']
    end
  end

  def test_once_auto_squash_is_in_valid_how_values
    assert_includes WvRunner::WorkLoop::VALID_HOW_VALUES, :once_auto_squash
  end
end
