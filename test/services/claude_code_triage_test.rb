# frozen_string_literal: true

require 'test_helper'

class ClaudeCodeTriageTest < Minitest::Test
  def test_triage_inherits_from_claude_code_base
    assert WvRunner::ClaudeCode::Triage < WvRunner::ClaudeCodeBase
  end

  def test_triage_uses_haiku_model
    triage = WvRunner::ClaudeCode::Triage.new
    assert_equal 'haiku', triage.send(:model_name)
  end

  def test_triage_does_not_accept_edits
    triage = WvRunner::ClaudeCode::Triage.new
    refute triage.send(:accept_edits?)
  end

  def test_triage_responds_to_run
    triage = WvRunner::ClaudeCode::Triage.new
    assert_respond_to triage, :run
  end

  def test_instructions_include_model_selection_rules
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=7' do
        triage = WvRunner::ClaudeCode::Triage.new
        instructions = triage.send(:build_instructions)

        assert_includes instructions, 'recommended_model'
        assert_includes instructions, 'opus'
        assert_includes instructions, 'sonnet'
        assert_includes instructions, 'WVRUNNER_RESULT'
      end
    end
  end

  def test_instructions_use_next_url_without_task_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=7' do
        triage = WvRunner::ClaudeCode::Triage.new
        instructions = triage.send(:build_instructions)

        assert_includes instructions, '@next?project_relative_id=7'
      end
    end
  end

  def test_instructions_use_direct_url_with_task_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=7' do
        triage = WvRunner::ClaudeCode::Triage.new(task_id: 456)
        instructions = triage.send(:build_instructions)

        assert_includes instructions, 'workvector://pieces/jchsoft/456'
        refute_includes instructions, '@next'
      end
    end
  end

  def test_instructions_include_resuming_field
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=7' do
        triage = WvRunner::ClaudeCode::Triage.new
        instructions = triage.send(:build_instructions)

        assert_includes instructions, 'resuming'
        assert_includes instructions, 'git branch --show-current'
      end
    end
  end

  def test_branch_check_comes_before_task_fetch_in_instructions
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=7' do
        triage = WvRunner::ClaudeCode::Triage.new
        instructions = triage.send(:build_instructions)

        branch_pos = instructions.index('BRANCH & RESUME DETECTION')
        fetch_pos = instructions.index('FETCH TASK')
        analyze_pos = instructions.index('ANALYZE')

        assert branch_pos, 'Instructions must include BRANCH & RESUME DETECTION step'
        assert fetch_pos, 'Instructions must include FETCH TASK step'
        assert analyze_pos, 'Instructions must include ANALYZE step'
        assert branch_pos < fetch_pos, 'Branch check must come before task fetch'
        assert fetch_pos < analyze_pos, 'Task fetch must come before analyze'
      end
    end
  end

  def test_instructions_include_pr_fallback_for_branches_without_task_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=7' do
        triage = WvRunner::ClaudeCode::Triage.new
        instructions = triage.send(:build_instructions)

        assert_includes instructions, 'gh pr list'
        assert_includes instructions, 'mcptask.online'
      end
    end
  end

  def test_instructions_only_allow_opus_or_sonnet
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=7' do
        triage = WvRunner::ClaudeCode::Triage.new
        instructions = triage.send(:build_instructions)

        assert_includes instructions, 'recommended_model MUST be exactly "opus" or "sonnet"'
        refute_includes instructions, 'opusplan'
      end
    end
  end

  def test_instructions_include_classification_criteria
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=7' do
        triage = WvRunner::ClaudeCode::Triage.new
        instructions = triage.send(:build_instructions)

        assert_includes instructions, 'Story'
        assert_includes instructions, 'Frontend'
        assert_includes instructions, 'Simple backend'
        assert_includes instructions, 'attachment'
      end
    end
  end

  # Story triage tests

  def test_story_triage_uses_story_instructions
    triage = WvRunner::ClaudeCode::Triage.new(story_id: 8965)
    instructions = triage.send(:build_instructions)

    assert_includes instructions, 'LOAD STORY'
    assert_includes instructions, 'workvector://pieces/jchsoft/8965'
    assert_includes instructions, 'subtask'
    refute_includes instructions, 'BRANCH & RESUME DETECTION'
  end

  def test_story_triage_includes_model_selection_rules
    triage = WvRunner::ClaudeCode::Triage.new(story_id: 8965)
    instructions = triage.send(:build_instructions)

    assert_includes instructions, 'recommended_model'
    assert_includes instructions, 'opus'
    assert_includes instructions, 'sonnet'
    assert_includes instructions, 'WVRUNNER_RESULT'
  end

  def test_story_triage_does_not_include_branch_detection
    triage = WvRunner::ClaudeCode::Triage.new(story_id: 8965)
    instructions = triage.send(:build_instructions)

    refute_includes instructions, 'git branch --show-current'
    refute_includes instructions, 'BRANCH & RESUME DETECTION'
  end

  def test_story_triage_finds_incomplete_subtasks
    triage = WvRunner::ClaudeCode::Triage.new(story_id: 8965)
    instructions = triage.send(:build_instructions)

    assert_includes instructions, 'Schváleno'
    assert_includes instructions, 'Hotovo?'
    assert_includes instructions, 'progress < 100'
  end

  def test_standard_triage_without_story_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=7' do
        triage = WvRunner::ClaudeCode::Triage.new
        instructions = triage.send(:build_instructions)

        assert_includes instructions, 'BRANCH & RESUME DETECTION'
        refute_includes instructions, 'LOAD STORY'
      end
    end
  end
end
