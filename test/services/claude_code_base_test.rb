# frozen_string_literal: true

require 'test_helper'

class ClaudeCodeBaseTest < Minitest::Test
  def test_claude_code_base_cannot_be_instantiated_with_abstract_methods
    base = WvRunner::ClaudeCodeBase.new
    assert_raises(NotImplementedError) { base.send(:build_instructions, nil) }
  end

  def test_find_json_end_with_simple_json
    base = WvRunner::ClaudeCodeBase.new
    json_str = '{"status": "success"}'
    json_end = base.send(:find_json_end, json_str)
    assert_equal json_str.length, json_end
  end

  def test_find_json_end_with_nested_json
    base = WvRunner::ClaudeCodeBase.new
    json_str = '{"status": "success", "data": {"nested": "value"}}'
    json_end = base.send(:find_json_end, json_str)
    assert_equal json_str.length, json_end
  end

  def test_find_json_end_handles_escaped_quotes
    base = WvRunner::ClaudeCodeBase.new
    json_str = '{"text": "He said \\"hello\\"", "status": "done"}'
    json_end = base.send(:find_json_end, json_str)
    assert_equal json_str.length, json_end
  end

  def test_find_json_end_returns_nil_for_unclosed_json
    base = WvRunner::ClaudeCodeBase.new
    json_str = '{"status": "success"'
    json_end = base.send(:find_json_end, json_str)
    assert_nil json_end
  end

  def test_project_relative_id_loaded_from_claude_md
    File.stub :exist?, true do
      File.stub :read, "## WorkVector\n- project_relative_id=42" do
        base = WvRunner::ClaudeCodeBase.new
        project_id = base.send(:project_relative_id)
        assert_equal 42, project_id
      end
    end
  end

  def test_project_relative_id_returns_nil_when_file_not_found
    File.stub :exist?, false do
      base = WvRunner::ClaudeCodeBase.new
      project_id = base.send(:project_relative_id)
      assert_nil project_id
    end
  end

  def test_error_result_creates_error_hash
    base = WvRunner::ClaudeCodeBase.new
    result = base.send(:error_result, 'Test error message')
    assert_equal 'error', result['status']
    assert_equal 'Test error message', result['message']
  end

  def test_inject_state_into_instructions_with_no_state
    base = WvRunner::ClaudeCodeBase.new
    template = 'Original instructions with {{WORKFLOW_STATE}}'
    result = base.send(:inject_state_into_instructions, template, nil)
    assert_equal template, result
  end

  def test_inject_state_into_instructions_with_state
    base = WvRunner::ClaudeCodeBase.new
    template = 'Instructions with state: {{WORKFLOW_STATE}}'
    state = { task_id: 123, name: 'Test Task' }
    result = base.send(:inject_state_into_instructions, template, state)
    assert_includes result, '"task_id":123'
    assert_includes result, '"name":"Test Task"'
    refute_includes result, '{{WORKFLOW_STATE}}'
  end
end
