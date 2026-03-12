# frozen_string_literal: true

require 'test_helper'

class WorkLoopReviewTest < Minitest::Test
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

  def test_execute_with_reviews_stops_on_quota_exceeded
    mock = Object.new
    def mock.run
      { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 8 } }
    end

    decider_mock = Object.new
    def decider_mock.should_stop?
      true
    end

    WvRunner::ClaudeCode::Reviews.stub(:new, mock) do
      WvRunner::Decider.stub(:new, decider_mock) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:reviews)

        assert_instance_of Array, results
        assert_equal 1, results.length
        assert_equal 'success', results.first['status']
      end
    end
  end

  def test_execute_with_reviews_ignore_quota_skips_check
    call_count = [0]
    mock = Object.new
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 8 } } : { 'status' => 'no_reviews' }
    end

    WvRunner::ClaudeCode::Reviews.stub(:new, mock) do
      Kernel.stub(:sleep, nil) do
        loop_instance = WvRunner::WorkLoop.new(ignore_quota: true)
        results = loop_instance.execute(:reviews)

        assert_instance_of Array, results
        assert_equal 2, results.length
      end
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
end
