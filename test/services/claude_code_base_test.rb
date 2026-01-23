# frozen_string_literal: true

require 'test_helper'

class ClaudeCodeBaseTest < Minitest::Test
  def test_claude_code_base_cannot_be_instantiated_with_abstract_methods
    base = WvRunner::ClaudeCodeBase.new
    assert_raises(NotImplementedError) { base.send(:build_instructions) }
  end

  def test_model_name_is_abstract
    base = WvRunner::ClaudeCodeBase.new
    assert_raises(NotImplementedError) { base.send(:model_name) }
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

  def test_timeout_constant_is_defined
    assert_equal 3600, WvRunner::ClaudeCodeBase::CLAUDE_EXECUTION_TIMEOUT
  end

  def test_parse_result_returns_parsed_json_with_task_worked
    mock_output = 'WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": 8, "task_estimated": 2}}'
    base = WvRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 1.5)

    assert_equal 'success', result['status']
    assert_equal 8, result['hours']['per_day']
    assert_equal 2, result['hours']['task_estimated']
    assert_equal 1.5, result['hours']['task_worked']
  end

  def test_parse_result_handles_error_when_result_not_found
    mock_output = 'Some output without JSON'
    base = WvRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 0.5)

    assert_equal 'error', result['status']
    assert_equal 'No WVRUNNER_RESULT found in output', result['message']
  end

  def test_parse_result_handles_invalid_json
    mock_output = 'WVRUNNER_RESULT: {invalid json}'
    base = WvRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 0.5)

    assert_equal 'error', result['status']
    assert_match(/Failed to parse JSON/, result['message'])
  end

  def test_parse_result_handles_json_with_escaped_quotes_from_real_claude_output
    # Real-world case: Claude outputs JSON with escaped quotes in markdown code block
    mock_output = "Perfect! I've loaded the task information. Let me parse and display the details:\n\n## Task Information\n\n**Task Name:** (ActionDispatch::MissingController) \"uninitialized constant Api::OfficesController\"\n\n```json\nWVRUNNER_RESULT: {\\\"status\\\": \\\"success\\\", \\\"task_info\\\": {\\\"name\\\": \\\"(ActionDispatch::MissingController) \\\\\\\"uninitialized constant Api::OfficesController\\\\\\\"\\\", \\\"id\\\": 9005, \\\"description\\\": \\\"Test description\\\", \\\"status\\\": \\\"Nove\\\", \\\"priority\\\": \\\"Urgentni\\\", \\\"assigned_user\\\": \\\"Karel Mracek\\\", \\\"scrum_points\\\": \\\"Mirne obtizne\\\"}, \\\"hours\\\": {\\\"per_day\\\": 8, \\\"task_estimated\\\": 1.0}}\n```"

    base = WvRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 0.25)

    assert_equal 'success', result['status'], 'Should parse JSON with escaped quotes successfully'
    assert_equal 9005, result['task_info']['id']
    assert_equal 'Karel Mracek', result['task_info']['assigned_user']
    assert_equal 8, result['hours']['per_day']
    assert_equal 1.0, result['hours']['task_estimated']
    assert_equal 0.25, result['hours']['task_worked']
  end

  def test_accept_edits_defaults_to_true
    base = WvRunner::ClaudeCodeBase.new
    assert base.send(:accept_edits?)
  end

  # Tests for retry and error handling constants
  def test_max_retry_attempts_constant_is_defined
    assert_equal 3, WvRunner::ClaudeCodeBase::MAX_RETRY_ATTEMPTS
  end

  def test_retry_wait_seconds_constant_is_defined
    assert_equal 30, WvRunner::ClaudeCodeBase::RETRY_WAIT_SECONDS
  end

  # Tests for StreamClosedError exception
  def test_stream_closed_error_exists
    assert_kind_of Class, WvRunner::StreamClosedError
    assert WvRunner::StreamClosedError < StandardError
  end

  def test_stream_closed_error_can_be_raised_with_message
    error = WvRunner::StreamClosedError.new('test error message')
    assert_equal 'test error message', error.message
  end

  # Tests for MissingMarkerError exception
  def test_missing_marker_error_exists
    assert_kind_of Class, WvRunner::MissingMarkerError
    assert WvRunner::MissingMarkerError < StandardError
  end

  def test_missing_marker_error_can_be_raised_with_message
    error = WvRunner::MissingMarkerError.new('marker not found')
    assert_equal 'marker not found', error.message
  end

  # Tests for build_command with continue_session
  def test_build_command_without_continue_session
    base = WvRunner::ClaudeCodeBase.new
    base.define_singleton_method(:model_name) { 'opus' }

    cmd = base.send(:build_command, '/usr/bin/claude', 'test instructions', continue_session: false)

    assert_equal '/usr/bin/claude', cmd[0]
    refute_includes cmd, '--continue'
    assert_includes cmd, '-p'
    assert_includes cmd, 'test instructions'
    assert_includes cmd, '--model'
    assert_includes cmd, 'opus'
  end

  def test_build_command_with_continue_session
    base = WvRunner::ClaudeCodeBase.new
    base.define_singleton_method(:model_name) { 'opus' }

    cmd = base.send(:build_command, '/usr/bin/claude', 'test instructions', continue_session: true)

    assert_equal '/usr/bin/claude', cmd[0]
    assert_equal '--continue', cmd[1], 'Continue flag should be second element'
    assert_includes cmd, '-p'
    assert_includes cmd, 'test instructions'
  end

  # Tests for stream_lines method
  def test_stream_lines_yields_each_line
    base = WvRunner::ClaudeCodeBase.new
    io = StringIO.new("line1\nline2\nline3\n")
    lines = []

    base.send(:stream_lines, io) { |line| lines << line.strip }

    assert_equal %w[line1 line2 line3], lines
  end

  # Tests for handle_stream_error method
  def test_handle_stream_error_returns_early_when_stopping
    base = WvRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@stopping, true)

    yielded = false
    base.send(:handle_stream_error, IOError.new('test'), 'stdout') { yielded = true }

    refute yielded, 'Should not yield when stopping'
  end

  def test_handle_stream_error_yields_error_message_when_not_stopping
    base = WvRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@stopping, false)

    error_msg = nil
    base.send(:handle_stream_error, IOError.new('stream closed'), 'stdout') { |msg| error_msg = msg }

    assert_match(/stdout stream closed unexpectedly/, error_msg)
    assert_match(/stream closed/, error_msg)
  end

  # Tests for handle_recoverable_error method
  def test_handle_recoverable_error_returns_nil_for_retry
    base = WvRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@retry_count, 0)
    start_time = Time.now

    result = base.send(:handle_recoverable_error, 'Timeout', start_time)

    assert_nil result, 'Should return nil to signal retry'
  end

  def test_handle_recoverable_error_returns_error_when_max_retries_reached
    base = WvRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@retry_count, 2) # MAX_RETRY_ATTEMPTS - 1
    start_time = Time.now

    result = base.send(:handle_recoverable_error, 'Timeout', start_time)

    assert_equal 'error', result['status']
    assert_match(/retries exhausted/, result['message'])
  end

  # Tests for initialization of new instance variables
  def test_initialize_sets_stopping_to_false
    base = WvRunner::ClaudeCodeBase.new
    refute base.instance_variable_get(:@stopping)
  end

  def test_initialize_sets_retry_count_to_zero
    base = WvRunner::ClaudeCodeBase.new
    assert_equal 0, base.instance_variable_get(:@retry_count)
  end

  def test_initialize_sets_marker_retry_mode_to_false
    base = WvRunner::ClaudeCodeBase.new
    refute base.instance_variable_get(:@marker_retry_mode)
  end

  # Tests for handle_marker_retry method
  def test_handle_marker_retry_returns_nil_for_retry
    base = WvRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@retry_count, 0)
    start_time = Time.now

    result = base.send(:handle_marker_retry, start_time)

    assert_nil result, 'Should return nil to signal retry'
  end

  def test_handle_marker_retry_sets_marker_retry_mode
    base = WvRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@retry_count, 0)
    start_time = Time.now

    base.send(:handle_marker_retry, start_time)

    assert base.instance_variable_get(:@marker_retry_mode), 'Should set marker_retry_mode to true'
  end

  def test_handle_marker_retry_returns_error_when_max_retries_reached
    base = WvRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@retry_count, 2) # MAX_RETRY_ATTEMPTS - 1
    start_time = Time.now

    result = base.send(:handle_marker_retry, start_time)

    assert_equal 'error', result['status']
    assert_match(/Missing WVRUNNER_RESULT/, result['message'])
    assert_match(/retries exhausted/, result['message'])
  end

  # Tests for build_marker_retry_instructions method
  def test_build_marker_retry_instructions_contains_marker_format
    base = WvRunner::ClaudeCodeBase.new
    instructions = base.send(:build_marker_retry_instructions)

    assert_includes instructions, 'WVRUNNER_RESULT:'
    assert_includes instructions, 'status'
    assert_includes instructions, 'success'
    assert_includes instructions, 'hours'
    assert_includes instructions, 'per_day'
    assert_includes instructions, 'task_estimated'
  end

  def test_build_marker_retry_instructions_references_workvector
    base = WvRunner::ClaudeCodeBase.new
    instructions = base.send(:build_marker_retry_instructions)

    assert_includes instructions, 'workvector://user'
    assert_includes instructions, 'hour_goal'
    assert_includes instructions, 'duration_best'
  end
end
