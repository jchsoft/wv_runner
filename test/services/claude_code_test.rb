# frozen_string_literal: true

require 'test_helper'

class ClaudeCodeHonestTest < Minitest::Test
  def test_honest_responds_to_run
    honest = WvRunner::ClaudeCode::Honest.new
    assert_respond_to honest, :run
  end

  def test_honest_inherits_from_claude_code_base
    assert WvRunner::ClaudeCode::Honest < WvRunner::ClaudeCodeBase
  end

  def test_honest_uses_opus_model
    honest = WvRunner::ClaudeCode::Honest.new
    assert_equal 'opus', honest.send(:model_name)
  end

  def test_honest_accepts_edits
    honest = WvRunner::ClaudeCode::Honest.new
    assert honest.send(:accept_edits?)
  end

  def test_instructions_includes_project_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        honest = WvRunner::ClaudeCode::Honest.new
        instructions = honest.send(:build_instructions)
        assert_includes instructions, 'project_relative_id=99'
        assert_includes instructions, 'workvector://pieces/jchsoft/@next'
        assert_includes instructions, 'WVRUNNER_RESULT'
      end
    end
  end

  def test_instructions_includes_git_checkout_main
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        honest = WvRunner::ClaudeCode::Honest.new
        instructions = honest.send(:build_instructions)
        assert_includes instructions, 'git checkout main'
        assert_includes instructions, 'GIT: Make sure you are on the main branch'
        assert_includes instructions, 'clean, stable state'
      end
    end
  end

  def test_instructions_raises_when_project_id_not_found
    File.stub :exist?, false do
      honest = WvRunner::ClaudeCode::Honest.new
      assert_raises(RuntimeError) do
        honest.send(:build_instructions)
      end
    end
  end

  def test_instructions_includes_task_status_check
    File.stub :exist?, true do
      File.stub :read, "project_relative_id=7\n" do
        honest = WvRunner::ClaudeCode::Honest.new
        instructions = honest.send(:build_instructions)
        assert_includes instructions, 'NOT ALREADY STARTED'
      end
    end
  end

  def test_instructions_includes_workflow_steps
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        honest = WvRunner::ClaudeCode::Honest.new
        instructions = honest.send(:build_instructions)
        assert_includes instructions, 'CREATE A NEW BRANCH'
        assert_includes instructions, 'COMPLETE the task'
        assert_includes instructions, 'COMMIT your changes'
        assert_includes instructions, 'RUN ALL TESTS'
        assert_includes instructions, 'PUSH the branch'
        assert_includes instructions, 'CREATE A PULL REQUEST'
      end
    end
  end
end

class ClaudeCodeDryTest < Minitest::Test
  def test_dry_responds_to_run
    dry = WvRunner::ClaudeCode::Dry.new
    assert_respond_to dry, :run
  end

  def test_dry_inherits_from_claude_code_base
    assert WvRunner::ClaudeCode::Dry < WvRunner::ClaudeCodeBase
  end

  def test_dry_uses_haiku_model
    dry = WvRunner::ClaudeCode::Dry.new
    assert_equal 'haiku', dry.send(:model_name)
  end

  def test_dry_does_not_accept_edits
    dry = WvRunner::ClaudeCode::Dry.new
    refute dry.send(:accept_edits?)
  end

  def test_instructions_dry_includes_project_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=77' do
        dry = WvRunner::ClaudeCode::Dry.new
        instructions = dry.send(:build_instructions)
        assert_includes instructions, 'project_relative_id=77'
        assert_includes instructions, 'workvector://pieces/jchsoft/@next'
        assert_includes instructions, 'WVRUNNER_RESULT'
        assert_includes instructions, 'DRY RUN'
        assert_includes instructions, 'DO NOT create a branch'
      end
    end
  end

  def test_instructions_dry_includes_task_info_fields
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=77' do
        dry = WvRunner::ClaudeCode::Dry.new
        instructions = dry.send(:build_instructions)
        assert_includes instructions, 'task_info'
        assert_includes instructions, 'name'
        assert_includes instructions, 'description'
        assert_includes instructions, 'status'
        assert_includes instructions, 'priority'
      end
    end
  end

  def test_instructions_dry_raises_when_project_id_not_found
    File.stub :exist?, false do
      dry = WvRunner::ClaudeCode::Dry.new
      assert_raises(RuntimeError) do
        dry.send(:build_instructions)
      end
    end
  end

  def test_instructions_dry_includes_duration_best_extraction
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=77' do
        dry = WvRunner::ClaudeCode::Dry.new
        instructions = dry.send(:build_instructions)
        assert_includes instructions, 'duration_best'
        assert_includes instructions, 'hodina'
        assert_includes instructions, 'den'
        assert_includes instructions, 'DEBUG'
        assert_includes instructions, 'task_estimated: Y'
      end
    end
  end

  def test_instructions_dry_prevents_modifications
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=77' do
        dry = WvRunner::ClaudeCode::Dry.new
        instructions = dry.send(:build_instructions)
        assert_includes instructions, 'DO NOT create a branch'
        assert_includes instructions, 'DO NOT modify any code'
        assert_includes instructions, 'DO NOT create a pull request'
      end
    end
  end
end
