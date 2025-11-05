require "test_helper"

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

    assert_equal "success", result["status"]
    assert_equal 8, result["hours"]["per_day"]
    assert_equal 2, result["hours"]["task_estimated"]
    assert_equal 1.5, result["hours"]["task_worked"]
  end

  def test_parse_result_handles_error_when_result_not_found
    mock_output = 'Some output without JSON'
    claude = WvRunner::ClaudeCode.new
    result = claude.send(:parse_result, mock_output, 0.5)

    assert_equal "error", result["status"]
    assert_equal "No WVRUNNER_RESULT found in output", result["message"]
  end

  def test_parse_result_handles_invalid_json
    mock_output = 'WVRUNNER_RESULT: {invalid json}'
    claude = WvRunner::ClaudeCode.new
    result = claude.send(:parse_result, mock_output, 0.5)

    assert_equal "error", result["status"]
    assert_match /Failed to parse JSON/, result["message"]
  end

  def test_parse_result_handles_json_with_escaped_quotes_from_real_claude_output
    # Real-world case from task #9005: Claude outputs JSON with escaped quotes
    # Raw from Claude: {\"status\": \"success\", \"task_info\": {\"name\": \"(ActionDispatch::MissingController) \\\"uninitialized constant Api::OfficesController\\\"\", ...}}
    # After two-step unescape: {"status": "success", "task_info": {"name": "(ActionDispatch::MissingController) \"uninitialized constant Api::OfficesController\"", ...}}
    mock_output = 'WVRUNNER_RESULT: {\"status\": \"success\", \"task_info\": {\"name\": \"(ActionDispatch::MissingController) \\\"uninitialized constant Api::OfficesController\\\"\", \"id\": 9005, \"description\": \"Bot/hacker attempting to access invalid endpoint https://zuboklik.cz/api/config.env which incorrectly routes to Api::OfficesController. Need to investigate routing issue, write test, fix problem, verify test passes.\", \"status\": \"Nové\", \"priority\": \"Urgentní\", \"assigned_user\": \"Karel Mráček\", \"scrum_points\": \"Mírně obtížné (5)\"}, \"hours\": {\"per_day\": 8, \"task_estimated\": 1.0}}'

    claude = WvRunner::ClaudeCode.new
    result = claude.send(:parse_result, mock_output, 0.25)

    # The key assertion: this should parse successfully despite quotes in the error message
    assert_equal "success", result["status"], "Should parse JSON with escaped quotes successfully"
    assert_equal 9005, result["task_info"]["id"]
    assert_equal "Karel Mráček", result["task_info"]["assigned_user"]
    assert_equal "Urgentní", result["task_info"]["priority"]
    assert_equal 8, result["hours"]["per_day"]
    assert_equal 1.0, result["hours"]["task_estimated"]
    assert_equal 0.25, result["hours"]["task_worked"]
    # Verify the task name with error message is properly extracted with literal quotes inside
    assert_includes result["task_info"]["name"], "ActionDispatch::MissingController"
    assert_includes result["task_info"]["name"], "uninitialized constant Api::OfficesController"
    # Verify that quoted part has actual quote characters (not escaped)
    assert_includes result["task_info"]["name"], '"uninitialized constant Api::OfficesController"'
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
      File.stub :read, "## Some other content" do
        claude = WvRunner::ClaudeCode.new
        project_id = claude.send(:project_relative_id)
        assert_nil project_id
      end
    end
  end

  def test_instructions_includes_project_id
    File.stub :exist?, true do
      File.stub :read, "project_relative_id=99" do
        claude = WvRunner::ClaudeCode.new
        instructions = claude.send(:instructions)
        assert_includes instructions, "project_relative_id=99"
        assert_includes instructions, "workvector://pieces/jchsoft/@next"
        assert_includes instructions, "WVRUNNER_RESULT"
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
      File.stub :read, "project_relative_id=77" do
        claude = WvRunner::ClaudeCode.new
        instructions = claude.send(:instructions_dry)
        assert_includes instructions, "project_relative_id=77"
        assert_includes instructions, "workvector://pieces/jchsoft/@next"
        assert_includes instructions, "WVRUNNER_RESULT"
        assert_includes instructions, "DRY RUN"
        assert_includes instructions, "DO NOT create a branch"
      end
    end
  end

  def test_instructions_dry_includes_task_info_fields
    File.stub :exist?, true do
      File.stub :read, "project_relative_id=77" do
        claude = WvRunner::ClaudeCode.new
        instructions = claude.send(:instructions_dry)
        assert_includes instructions, "task_info"
        assert_includes instructions, "name"
        assert_includes instructions, "description"
        assert_includes instructions, "status"
        assert_includes instructions, "priority"
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
end
