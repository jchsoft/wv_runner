# frozen_string_literal: true

require 'test_helper'
require_relative 'triage_test_helper'

class WorkLoopTaskTest < Minitest::Test
  include TriageTestHelper

  # task_manual
  def test_execute_with_task_manual_requires_task_id
    loop_instance = WvRunner::WorkLoop.new
    error = assert_raises(ArgumentError) { loop_instance.execute(:task_manual) }
    assert_includes error.message, 'task_id is required'
  end

  def test_execute_with_task_manual_calls_task_manual_class
    mock = Object.new
    def mock.run
      { 'status' => 'success', 'task_id' => 456, 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } }
    end

    with_triage_stub(task_id: 456) do
      WvRunner::ClaudeCode::TaskManual.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new(task_id: 456)
        result = loop_instance.execute(:task_manual)

        assert_equal 'success', result['status']
        assert_equal 456, result['task_id']
      end
    end
  end

  def test_execute_with_task_manual_handles_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Error processing task' }
    end

    with_triage_stub(task_id: 456) do
      WvRunner::ClaudeCode::TaskManual.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new(task_id: 456)
        result = loop_instance.execute(:task_manual)

        assert_equal 'failure', result['status']
      end
    end
  end

  # task_auto_squash
  def test_execute_with_task_auto_squash_requires_task_id
    loop_instance = WvRunner::WorkLoop.new
    error = assert_raises(ArgumentError) { loop_instance.execute(:task_auto_squash) }
    assert_includes error.message, 'task_id is required'
  end

  def test_execute_with_task_auto_squash_calls_task_auto_squash_class
    mock = Object.new
    def mock.run
      { 'status' => 'success', 'task_id' => 456, 'hours' => { 'per_day' => 8, 'task_estimated' => 2 } }
    end

    with_triage_stub(task_id: 456) do
      WvRunner::ClaudeCode::TaskAutoSquash.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new(task_id: 456)
        result = loop_instance.execute(:task_auto_squash)

        assert_equal 'success', result['status']
        assert_equal 456, result['task_id']
      end
    end
  end

  def test_execute_with_task_auto_squash_handles_failure
    mock = Object.new
    def mock.run
      { 'status' => 'failure', 'message' => 'Error processing task' }
    end

    with_triage_stub(task_id: 456) do
      WvRunner::ClaudeCode::TaskAutoSquash.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new(task_id: 456)
        result = loop_instance.execute(:task_auto_squash)

        assert_equal 'failure', result['status']
      end
    end
  end

  def test_execute_with_task_auto_squash_handles_ci_failed
    mock = Object.new
    def mock.run
      { 'status' => 'ci_failed', 'message' => 'CI failed after retry' }
    end

    with_triage_stub(task_id: 456) do
      WvRunner::ClaudeCode::TaskAutoSquash.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new(task_id: 456)
        result = loop_instance.execute(:task_auto_squash)

        assert_equal 'ci_failed', result['status']
      end
    end
  end
end
