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
    assert_equal %i[once today daily once_dry], WvRunner::WorkLoop::VALID_HOW_VALUES
  end

  def test_execute_validates_how_parameter
    loop_instance = WvRunner::WorkLoop.new

    error = assert_raises(ArgumentError) { loop_instance.execute(:unknown) }
    assert_includes error.message, "Invalid 'how' value"
    assert_includes error.message, 'once, today, daily, once_dry'
  end

  def test_verbose_mode_can_be_enabled
    loop_instance = WvRunner::WorkLoop.new(verbose: true)
    assert_instance_of WvRunner::WorkLoop, loop_instance
  end
end
