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

  def test_parse_result_handles_escaped_json_with_backslashes
    # This is the real-world case from task 9003 where Claude outputs escaped JSON
    mock_output = 'WVRUNNER_RESULT: {\"status\": \"success\", \"task_info\": {\"name\": \"Divný záznam v událostech pacienta\", \"id\": 8595, \"description\": \"Bug in patient events display - strange record with cloud icon, exclamation mark, and missing method\", \"status\": \"Nové\", \"priority\": \"Počká to\", \"assigned_user\": \"Karel Mráček\", \"scrum_points\": \"L (8 points)\"}, \"hours\": {\"per_day\": 8, \"task_estimated\": 0}}'
    claude = WvRunner::ClaudeCode.new
    result = claude.send(:parse_result, mock_output, 0.5)

    assert_equal "success", result["status"]
    assert_equal 8595, result["task_info"]["id"]
    assert_equal "Divný záznam v událostech pacienta", result["task_info"]["name"]
    assert_equal "Karel Mráček", result["task_info"]["assigned_user"]
    assert_equal 8, result["hours"]["per_day"]
    assert_equal 0.5, result["hours"]["task_worked"]
  end

  def test_parse_result_handles_double_escaped_json_with_backslash_backslash
    # Edge case with double-escaped backslashes where actual text has \\\" (backslash-escaped-quote)
    # This simulates Claude output that contains literal backslash characters before quotes
    mock_output = 'WVRUNNER_RESULT: {\\\"status\\\": \\\"success\\\", \\\"task_info\\\": {\\\"name\\\": \\\"Test Task\\\", \\\"id\\\": 123}, \\\"hours\\\": {\\\"per_day\\\": 8, \\\"task_estimated\\\": 0}}'
    claude = WvRunner::ClaudeCode.new
    result = claude.send(:parse_result, mock_output, 1.0)

    assert_equal "success", result["status"]
    assert_equal 123, result["task_info"]["id"]
    assert_equal "Test Task", result["task_info"]["name"]
    assert_equal 8, result["hours"]["per_day"]
    assert_equal 1.0, result["hours"]["task_worked"]
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
end
