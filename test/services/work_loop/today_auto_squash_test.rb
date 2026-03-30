# frozen_string_literal: true

require 'test_helper'
require_relative 'triage_test_helper'

class WorkLoopTodayAutoSquashTest < Minitest::Test
  include TriageTestHelper

  def test_execute_with_today_auto_squash_calls_today_auto_squash_class
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

    with_triage_stub do
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
  end

  def test_execute_with_today_auto_squash_stops_on_no_more_tasks
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    with_triage_stub do
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
  end

  def test_execute_with_today_auto_squash_stops_immediately_after_workday
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks' }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::TodayAutoSquash.stub(:new, mock) do
        Time.stub(:now, Time.new(2025, 1, 15, 18, 0)) do
          loop_instance = WvRunner::WorkLoop.new
          results = loop_instance.execute(:today_auto_squash)

          assert_equal 1, results.length
          assert_equal 'no_more_tasks', results.first['status']
        end
      end
    end
  end

  def test_execute_with_today_auto_squash_stops_on_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Error processing task' }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::TodayAutoSquash.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:today_auto_squash)

        assert_instance_of Array, results
        assert_equal 1, results.length
        assert_equal 'failure', results.first['status']
      end
    end
  end

  def test_execute_with_today_auto_squash_stops_on_ci_failed
    mock = Object.new
    def mock.run
      { 'status' => 'ci_failed', 'message' => 'CI failed after retry' }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::TodayAutoSquash.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:today_auto_squash)

        assert_instance_of Array, results
        assert_equal 1, results.length
        assert_equal 'ci_failed', results.first['status']
      end
    end
  end

  def test_execute_with_today_auto_squash_continues_on_preexisting_test_errors
    call_count = [0]
    mock = Object.new
    mock.define_singleton_method(:run) do
      call_count[0] += 1
      if call_count[0] == 1
        { 'status' => 'preexisting_test_errors', 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } }
      else
        { 'status' => 'no_more_tasks' }
      end
    end

    with_triage_stub do
      WvRunner::ClaudeCode::TodayAutoSquash.stub(:new, mock) do
        Kernel.stub(:sleep, nil) do
          loop_instance = WvRunner::WorkLoop.new
          results = loop_instance.execute(:today_auto_squash)

          assert_equal 2, results.length
          assert_equal 'preexisting_test_errors', results.first['status']
          assert_equal 'no_more_tasks', results.last['status']
        end
      end
    end
  end

  def test_execute_with_today_auto_squash_checks_quota
    mock = Object.new
    def mock.run
      { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 8 } }
    end

    decider_mock = Object.new
    def decider_mock.should_stop?
      true
    end

    with_triage_stub do
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
  end
end
