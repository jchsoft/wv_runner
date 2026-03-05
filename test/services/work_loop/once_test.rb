# frozen_string_literal: true

require 'test_helper'
require_relative 'triage_test_helper'

class WorkLoopOnceTest < Minitest::Test
  include TriageTestHelper

  def test_execute_with_once_calls_honest
    mock = Object.new
    def mock.run
      { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2, 'task_worked' => 0.5 } }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::Honest.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        result = loop_instance.execute(:once)

        assert_equal 'success', result['status']
        assert_equal 8, result['hours']['per_day']
      end
    end
  end

  def test_execute_with_once_handles_error
    mock = Object.new
    def mock.run
      { 'status' => 'error', 'message' => 'Task loading failed' }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::Honest.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        result = loop_instance.execute(:once)

        assert_equal 'error', result['status']
        assert_equal 'Task loading failed', result['message']
      end
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

  def test_execute_with_once_auto_squash_calls_once_auto_squash_class
    mock = Object.new
    def mock.run
      { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::OnceAutoSquash.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        result = loop_instance.execute(:once_auto_squash)

        assert_equal 'success', result['status']
        assert_equal 8, result['hours']['per_day']
      end
    end
  end

  def test_execute_with_once_auto_squash_handles_no_more_tasks
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::OnceAutoSquash.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        result = loop_instance.execute(:once_auto_squash)

        assert_equal 'no_more_tasks', result['status']
      end
    end
  end

  def test_execute_with_once_auto_squash_handles_ci_failed
    mock = Object.new
    def mock.run
      { 'status' => 'ci_failed', 'message' => 'CI failed after retry' }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::OnceAutoSquash.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        result = loop_instance.execute(:once_auto_squash)

        assert_equal 'ci_failed', result['status']
      end
    end
  end

  def test_execute_with_once_auto_squash_handles_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Some error' }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::OnceAutoSquash.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        result = loop_instance.execute(:once_auto_squash)

        assert_equal 'failure', result['status']
      end
    end
  end
end
