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
end
