# frozen_string_literal: true

require 'test_helper'

class WorkLoopStoryTest < Minitest::Test
  # Story modes skip triage (always opus per rule), no triage stub needed

  def test_execute_with_story_manual_requires_story_id
    loop_instance = WvRunner::WorkLoop.new
    error = assert_raises(ArgumentError) { loop_instance.execute(:story_manual) }
    assert_includes error.message, 'story_id is required'
  end

  def test_execute_with_story_manual_calls_story_manual_class
    call_count = [0]
    mock = Object.new
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

  def test_execute_with_story_auto_squash_requires_story_id
    loop_instance = WvRunner::WorkLoop.new
    error = assert_raises(ArgumentError) { loop_instance.execute(:story_auto_squash) }
    assert_includes error.message, 'story_id is required'
  end

  def test_execute_with_story_auto_squash_calls_story_auto_squash_class
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
end
