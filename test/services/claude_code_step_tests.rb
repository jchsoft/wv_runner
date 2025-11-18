# frozen_string_literal: true

require 'test_helper'

class ClaudeCodeStep1Test < Minitest::Test
  def test_step1_responds_to_run
    step1 = WvRunner::ClaudeCodeStep1.new
    assert_respond_to step1, :run
  end

  def test_step1_build_instructions_includes_project_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        step1 = WvRunner::ClaudeCodeStep1.new
        instructions = step1.send(:build_instructions, nil)
        assert_includes instructions, 'project_relative_id=99'
        assert_includes instructions, 'STEP 1: TASK AND PROTOTYPE'
      end
    end
  end

  def test_step1_inherits_from_claude_code_base
    step1 = WvRunner::ClaudeCodeStep1.new
    assert_kind_of WvRunner::ClaudeCodeBase, step1
  end
end

class ClaudeCodeStep2Test < Minitest::Test
  def test_step2_responds_to_run
    step2 = WvRunner::ClaudeCodeStep2.new
    assert_respond_to step2, :run
  end

  def test_step2_build_instructions_includes_project_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        step2 = WvRunner::ClaudeCodeStep2.new
        instructions = step2.send(:build_instructions, nil)
        assert_includes instructions, 'STEP 2: REFACTOR AND FIX TESTS'
      end
    end
  end

  def test_step2_build_instructions_with_input_state
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=7' do
        step2 = WvRunner::ClaudeCodeStep2.new
        input_state = { task_id: 123, branch_name: 'feature/test' }
        instructions = step2.send(:build_instructions, input_state)
        assert_includes instructions, 'feature/test'
      end
    end
  end

  def test_step2_mentions_refactoring_guidelines
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=7' do
        step2 = WvRunner::ClaudeCodeStep2.new
        instructions = step2.send(:build_instructions, nil)
        assert_includes instructions, 'Ruby/Rails'
      end
    end
  end

  def test_step2_inherits_from_claude_code_base
    step2 = WvRunner::ClaudeCodeStep2.new
    assert_kind_of WvRunner::ClaudeCodeBase, step2
  end
end

class ClaudeCodeStep3Test < Minitest::Test
  def test_step3_responds_to_run
    step3 = WvRunner::ClaudeCodeStep3.new
    assert_respond_to step3, :run
  end

  def test_step3_build_instructions_includes_project_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        step3 = WvRunner::ClaudeCodeStep3.new
        instructions = step3.send(:build_instructions, nil)
        assert_includes instructions, 'STEP 3: PUSH AND CREATE PULL REQUEST'
      end
    end
  end

  def test_step3_mentions_pr_workflow
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=7' do
        step3 = WvRunner::ClaudeCodeStep3.new
        instructions = step3.send(:build_instructions, nil)
        assert_includes instructions, 'PUSH'
        assert_includes instructions, 'PULL REQUEST'
      end
    end
  end

  def test_step3_inherits_from_claude_code_base
    step3 = WvRunner::ClaudeCodeStep3.new
    assert_kind_of WvRunner::ClaudeCodeBase, step3
  end
end
