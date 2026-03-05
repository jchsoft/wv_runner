# frozen_string_literal: true

require 'test_helper'
require_relative 'triage_test_helper'

class WorkLoopQueueTest < Minitest::Test
  include TriageTestHelper

  # queue_auto_squash
  def test_execute_with_queue_auto_squash_calls_queue_auto_squash_class
    call_count = [0]
    mock = Object.new
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } } : { 'status' => 'no_more_tasks' }
    end

    with_triage_stub do
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
  end

  def test_execute_with_queue_auto_squash_stops_on_no_more_tasks
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::QueueAutoSquash.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:queue_auto_squash)

        assert_instance_of Array, results
        assert_equal 1, results.length
        assert_equal 'no_more_tasks', results.first['status']
      end
    end
  end

  def test_execute_with_queue_auto_squash_stops_on_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Error processing task' }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::QueueAutoSquash.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:queue_auto_squash)

        assert_instance_of Array, results
        assert_equal 1, results.length
        assert_equal 'failure', results.first['status']
      end
    end
  end

  def test_execute_with_queue_auto_squash_stops_on_ci_failed
    mock = Object.new
    def mock.run
      { 'status' => 'ci_failed', 'message' => 'CI failed after retry' }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::QueueAutoSquash.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:queue_auto_squash)

        assert_instance_of Array, results
        assert_equal 1, results.length
        assert_equal 'ci_failed', results.first['status']
      end
    end
  end

  def test_execute_with_queue_auto_squash_does_not_check_quota
    call_count = [0]
    mock = Object.new
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } } : { 'status' => 'no_more_tasks' }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::QueueAutoSquash.stub(:new, mock) do
        Kernel.stub(:sleep, nil) do
          loop_instance = WvRunner::WorkLoop.new
          results = loop_instance.execute(:queue_auto_squash)

          assert_instance_of Array, results
          assert_equal 2, results.length
        end
      end
    end
  end

  # queue_manual
  def test_execute_with_queue_manual_calls_honest_class
    call_count = [0]
    mock = Object.new
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } } : { 'status' => 'no_more_tasks' }
    end

    with_triage_stub do
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
  end

  def test_execute_with_queue_manual_stops_on_no_more_tasks
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::Honest.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:queue_manual)

        assert_instance_of Array, results
        assert_equal 1, results.length
        assert_equal 'no_more_tasks', results.first['status']
      end
    end
  end

  def test_execute_with_queue_manual_stops_on_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Error processing task' }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::Honest.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:queue_manual)

        assert_instance_of Array, results
        assert_equal 1, results.length
        assert_equal 'failure', results.first['status']
      end
    end
  end

  def test_execute_with_queue_manual_does_not_check_quota
    call_count = [0]
    mock = Object.new
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } } : { 'status' => 'no_more_tasks' }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::Honest.stub(:new, mock) do
        Kernel.stub(:sleep, nil) do
          loop_instance = WvRunner::WorkLoop.new
          results = loop_instance.execute(:queue_manual)

          assert_instance_of Array, results
          assert_equal 2, results.length
        end
      end
    end
  end
end
