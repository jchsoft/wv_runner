# frozen_string_literal: true

require 'test_helper'

class WorkLoopTest < Minitest::Test
  def test_work_loop_responds_to_execute
    loop = WvRunner::WorkLoop.new
    assert_respond_to loop, :execute
  end

  def test_execute_with_once_multi_step_workflow
    # Create simple mock objects that respond to run
    mock1 = Object.new
    def mock1.run
      { 'status' => 'success', 'step' => 1, 'next_step' => 'refactor_and_tests', 'task_id' => 123,
        'branch_name' => 'test' }
    end

    mock2 = Object.new
    def mock2.run(_state)
      { 'status' => 'success', 'step' => 2, 'next_step' => 'push_and_pr', 'task_id' => 123, 'branch_name' => 'test' }
    end

    mock3 = Object.new
    def mock3.run(_state)
      { 'status' => 'success', 'step' => 3, 'complete' => true, 'task_id' => 123, 'branch_name' => 'test' }
    end

    # Stub the .new methods to return our mocks
    WvRunner::ClaudeCodeStep1.stub(:new, mock1) do
      WvRunner::ClaudeCodeStep2.stub(:new, mock2) do
        WvRunner::ClaudeCodeStep3.stub(:new, mock3) do
          loop = WvRunner::WorkLoop.new
          result = loop.execute(:once)

          assert_equal 'success', result['status']
          assert_equal 3, result['step']
          assert_equal true, result['complete']
        end
      end
    end
  end

  def test_execute_with_once_handles_step1_error
    # Mock Step1 to return error
    mock1 = Object.new
    def mock1.run
      { 'status' => 'error', 'message' => 'Task loading failed' }
    end

    WvRunner::ClaudeCodeStep1.stub(:new, mock1) do
      loop = WvRunner::WorkLoop.new
      result = loop.execute(:once)

      assert_equal 'error', result['status']
      assert_equal 'Task loading failed', result['message']
    end
  end

  def test_execute_with_once_loops_on_step2_refactor_request
    # Step1 result
    mock1 = Object.new
    def mock1.run
      { 'status' => 'success', 'step' => 1, 'next_step' => 'refactor_and_tests', 'task_id' => 123,
        'branch_name' => 'test' }
    end

    # Use a class-based mock for Step2 to handle multiple calls
    mock2_instance = Class.new do
      def initialize
        @call_count = 0
      end

      def run(_state)
        @call_count += 1
        if @call_count == 1
          { 'status' => 'success', 'step' => 2, 'next_step' => 'refactor_and_tests', 'task_id' => 123,
            'branch_name' => 'test' }
        else
          { 'status' => 'success', 'step' => 2, 'next_step' => 'push_and_pr', 'task_id' => 123,
            'branch_name' => 'test' }
        end
      end
    end.new

    mock3 = Object.new
    def mock3.run(_state)
      { 'status' => 'success', 'step' => 3, 'complete' => true, 'task_id' => 123, 'branch_name' => 'test' }
    end

    WvRunner::ClaudeCodeStep1.stub(:new, mock1) do
      WvRunner::ClaudeCodeStep2.stub(:new, mock2_instance) do
        WvRunner::ClaudeCodeStep3.stub(:new, mock3) do
          loop = WvRunner::WorkLoop.new
          result = loop.execute(:once)

          assert_equal 'success', result['status']
          assert_equal true, result['complete']
          assert_equal 2, mock2_instance.instance_variable_get(:@call_count)
        end
      end
    end
  end

  def test_execute_raises_on_invalid_how
    loop = WvRunner::WorkLoop.new
    assert_raises(ArgumentError) { loop.execute(:invalid) }
  end

  def test_execute_with_once_limits_step2_iterations
    # Step1 result
    mock1 = Object.new
    def mock1.run
      { 'status' => 'success', 'step' => 1, 'next_step' => 'refactor_and_tests', 'task_id' => 123,
        'branch_name' => 'test' }
    end

    # Step2 always requests another iteration (to trigger max limit)
    mock2 = Object.new
    def mock2.run(_state)
      { 'status' => 'success', 'step' => 2, 'next_step' => 'refactor_and_tests', 'task_id' => 123,
        'branch_name' => 'test' }
    end

    WvRunner::ClaudeCodeStep1.stub(:new, mock1) do
      WvRunner::ClaudeCodeStep2.stub(:new, mock2) do
        loop = WvRunner::WorkLoop.new
        result = loop.execute(:once)

        assert_equal 'error', result['status']
        assert_includes result['message'], 'Too many Step 2 iterations'
        assert_includes result['message'], '3'
      end
    end
  end

  def test_execute_with_once_validates_step1_result
    # Step1 returns incomplete result (missing required keys)
    mock1 = Object.new
    def mock1.run
      { 'status' => 'success', 'step' => 1 } # missing task_id and branch_name
    end

    WvRunner::ClaudeCodeStep1.stub(:new, mock1) do
      loop = WvRunner::WorkLoop.new
      result = loop.execute(:once)

      assert_equal 'error', result['status']
      assert_includes result['message'], 'missing required keys'
    end
  end

  def test_execute_with_once_validates_step2_result
    # Step1 result OK
    mock1 = Object.new
    def mock1.run
      { 'status' => 'success', 'step' => 1, 'next_step' => 'refactor_and_tests', 'task_id' => 123,
        'branch_name' => 'test' }
    end

    # Step2 returns incomplete result
    mock2 = Object.new
    def mock2.run(_state)
      { 'status' => 'success', 'step' => 2 } # missing task_id and branch_name
    end

    WvRunner::ClaudeCodeStep1.stub(:new, mock1) do
      WvRunner::ClaudeCodeStep2.stub(:new, mock2) do
        loop = WvRunner::WorkLoop.new
        result = loop.execute(:once)

        assert_equal 'error', result['status']
        assert_includes result['message'], 'missing required keys'
      end
    end
  end
end
