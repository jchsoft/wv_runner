require "test_helper"

class ClaudeCodeTest < Minitest::Test
  def test_claude_code_responds_to_run
    claude = WvRunner::ClaudeCode.new
    assert_respond_to claude, :run
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
end
