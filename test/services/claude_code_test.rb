require 'test_helper'

class ClaudeCodeTest < Minitest::Test
  def test_claude_code_responds_to_run
    claude = WvRunner::ClaudeCode.new
    assert_respond_to claude, :run
  end

  def test_claude_code_responds_to_run_dry
    claude = WvRunner::ClaudeCode.new
    assert_respond_to claude, :run_dry
  end

  def test_parse_result_returns_parsed_json_with_task_worked
    mock_output = 'WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": 8, "task_estimated": 2}}'
    claude = WvRunner::ClaudeCode.new
    result = claude.send(:parse_result, mock_output, 1.5)

    assert_equal 'success', result['status']
    assert_equal 8, result['hours']['per_day']
    assert_equal 2, result['hours']['task_estimated']
    assert_equal 1.5, result['hours']['task_worked']
  end

  def test_parse_result_handles_error_when_result_not_found
    mock_output = 'Some output without JSON'
    claude = WvRunner::ClaudeCode.new
    result = claude.send(:parse_result, mock_output, 0.5)

    assert_equal 'error', result['status']
    assert_equal 'No WVRUNNER_RESULT found in output', result['message']
  end

  def test_parse_result_handles_invalid_json
    mock_output = 'WVRUNNER_RESULT: {invalid json}'
    claude = WvRunner::ClaudeCode.new
    result = claude.send(:parse_result, mock_output, 0.5)

    assert_equal 'error', result['status']
    assert_match(/Failed to parse JSON/, result['message'])
  end

  def test_parse_result_handles_json_with_escaped_quotes_from_real_claude_output
    # Real-world case from task #9005: Claude outputs JSON with escaped quotes in markdown code block
    # This is the ACTUAL output format Claude produces with all the formatting and explanation text
    mock_output = "Perfect! I've loaded the task information. Let me parse and display the details:\n\n## Task Information\n\n**Task Name:** (ActionDispatch::MissingController) \"uninitialized constant Api::OfficesController\"\n\n**Task ID:** 9005\n\n**Status:** Nové (New)\n\n**Priority:** Urgentní (Urgent)\n\n**Type:** Chyba (Bug)\n\n**Assigned to:** Karel Mráček\n\n**Scrum Points:** Mírně obtížné (M = 5 points)\n\n**Duration Estimate:** 1 hodina (1 hour)\n\n**Description:**\n```\nAn ActionDispatch::MissingController occurred in #:\n\n uninitialized constant Api::OfficesController\n\nRequest Details:\n * URL        : https://zuboklik.cz/api/config.env\n * HTTP Method: GET\n * IP address : 45.148.10.99\n * Parameters : {\"controller\"=>\"api/offices\", \"action\"=>\"show\", \"code\"=>\"config\", \"format\"=>\"env\"}\n * Timestamp  : 2025-11-05 05:47:41 +0100\n * Server : 161.216.forpsi.net\n\nNotes:\n- Možný hack/bot pokus získat data z Zubokliku\n- Zajímavé: volá Api::OfficesController i když path je \"https://zuboklik.cz/api/config.env\"\n- Úkol: zjistit proč se tak děje\n- Napsat test, který problém vyvolá a otestuje že už nenastává\n- Opravit problém\n- Test by měl projít\n```\n\n---\n\n**[DEBUG] duration_best: '1 hodina' → task_estimated: 1.0**\n\n```json\nWVRUNNER_RESULT: {\\\"status\\\": \\\"success\\\", \\\"task_info\\\": {\\\"name\\\": \\\"(ActionDispatch::MissingController) \\\\\\\"uninitialized constant Api::OfficesController\\\\\\\"\\\", \\\"id\\\": 9005, \\\"description\\\": \\\"An ActionDispatch::MissingController occurred when accessing https://zuboklik.cz/api/config.env. The error shows Api::OfficesController being called even though the path requests config.env. Likely bot/hacker attempt. Task: investigate root cause, write test to reproduce and verify fix works, implement the fix, ensure test passes.\\\", \\\"status\\\": \\\"Nové\\\", \\\"priority\\\": \\\"Urgentní\\\", \\\"assigned_user\\\": \\\"Karel Mráček\\\", \\\"scrum_points\\\": \\\"Mírně obtížné\\\"}, \\\"hours\\\": {\\\"per_day\\\": 8, \\\"task_estimated\\\": 1.0}}\n```"

    claude = WvRunner::ClaudeCode.new
    result = claude.send(:parse_result, mock_output, 0.25)

    # The key assertion: this should parse successfully despite quotes in the error message
    assert_equal 'success', result['status'], 'Should parse JSON with escaped quotes successfully'
    assert_equal 9005, result['task_info']['id']
    assert_equal 'Karel Mráček', result['task_info']['assigned_user']
    assert_equal 'Urgentní', result['task_info']['priority']
    assert_equal 8, result['hours']['per_day']
    assert_equal 1.0, result['hours']['task_estimated']
    assert_equal 0.25, result['hours']['task_worked']
    # Verify the task name with error message is properly extracted with literal quotes inside
    assert_includes result['task_info']['name'], 'ActionDispatch::MissingController'
    assert_includes result['task_info']['name'], 'uninitialized constant Api::OfficesController'
    # Verify that quoted part has actual quote characters (not escaped)
    assert_includes result['task_info']['name'], '"uninitialized constant Api::OfficesController"'
  end

  def test_project_relative_id_loaded_from_claude_md
    File.stub :exist?, true do
      File.stub :read, "## WorkVector\n- project_relative_id=42" do
        claude = WvRunner::ClaudeCode.new
        project_id = claude.send(:project_relative_id)
        assert_equal 42, project_id
      end
    end
  end

  def test_project_relative_id_returns_nil_when_file_not_found
    File.stub :exist?, false do
      claude = WvRunner::ClaudeCode.new
      project_id = claude.send(:project_relative_id)
      assert_nil project_id
    end
  end

  def test_project_relative_id_returns_nil_when_pattern_not_found
    File.stub :exist?, true do
      File.stub :read, '## Some other content' do
        claude = WvRunner::ClaudeCode.new
        project_id = claude.send(:project_relative_id)
        assert_nil project_id
      end
    end
  end

  def test_instructions_includes_project_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        claude = WvRunner::ClaudeCode.new
        instructions = claude.send(:instructions)
        assert_includes instructions, 'project_relative_id=99'
        assert_includes instructions, 'workvector://pieces/jchsoft/@next'
        assert_includes instructions, 'WVRUNNER_RESULT'
      end
    end
  end

  def test_instructions_includes_git_checkout_main
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        claude = WvRunner::ClaudeCode.new
        instructions = claude.send(:instructions)
        assert_includes instructions, 'git checkout main'
        assert_includes instructions, 'GIT: Make sure you are on the main branch'
        assert_includes instructions, 'clean, stable state'
      end
    end
  end

  def test_instructions_raises_when_project_id_not_found
    File.stub :exist?, false do
      claude = WvRunner::ClaudeCode.new
      assert_raises(RuntimeError) do
        claude.send(:instructions)
      end
    end
  end

  def test_instructions_dry_includes_project_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=77' do
        claude = WvRunner::ClaudeCode.new
        instructions = claude.send(:instructions_dry)
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
        claude = WvRunner::ClaudeCode.new
        instructions = claude.send(:instructions_dry)
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
      claude = WvRunner::ClaudeCode.new
      assert_raises(RuntimeError) do
        claude.send(:instructions_dry)
      end
    end
  end

  def test_instructions_dry_includes_duration_best_extraction
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=77' do
        claude = WvRunner::ClaudeCode.new
        instructions = claude.send(:instructions_dry)
        assert_includes instructions, 'duration_best'
        assert_includes instructions, 'hodina'
        assert_includes instructions, 'den'
        assert_includes instructions, 'týden'
        assert_includes instructions, 'DEBUG'
        assert_includes instructions, 'task_estimated: Y'
      end
    end
  end

  def test_instructions_includes_task_status_check_before_starting_work
    # This test verifies the fix for task #9036: prevent duplicate task processing
    # The @next endpoint sometimes returns tasks that are already in progress
    # We need to check task status BEFORE starting work to prevent duplicates
    File.stub :exist?, true do
      File.stub :read, "project_relative_id=7\n" do
        claude = WvRunner::ClaudeCode.new
        instructions = claude.send(:instructions)

        assert_includes instructions, 'NOT ALREADY STARTED'
      end
    end
  end
end
