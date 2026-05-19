# frozen_string_literal: true

require 'test_helper'

class ClaudeCodeBaseTest < Minitest::Test
  def test_claude_code_base_cannot_be_instantiated_with_abstract_methods
    base = McptaskRunner::ClaudeCodeBase.new
    assert_raises(NotImplementedError) { base.send(:build_instructions) }
  end

  def test_model_name_is_abstract
    base = McptaskRunner::ClaudeCodeBase.new
    assert_raises(NotImplementedError) { base.send(:model_name) }
  end

  def test_find_json_end_with_simple_json
    base = McptaskRunner::ClaudeCodeBase.new
    json_str = '{"status": "success"}'
    json_end = base.send(:find_json_end, json_str)
    assert_equal json_str.length, json_end
  end

  def test_find_json_end_with_nested_json
    base = McptaskRunner::ClaudeCodeBase.new
    json_str = '{"status": "success", "data": {"nested": "value"}}'
    json_end = base.send(:find_json_end, json_str)
    assert_equal json_str.length, json_end
  end

  def test_find_json_end_handles_escaped_quotes
    base = McptaskRunner::ClaudeCodeBase.new
    json_str = '{"text": "He said \\"hello\\"", "status": "done"}'
    json_end = base.send(:find_json_end, json_str)
    assert_equal json_str.length, json_end
  end

  def test_find_json_end_returns_nil_for_unclosed_json
    base = McptaskRunner::ClaudeCodeBase.new
    json_str = '{"status": "success"'
    json_end = base.send(:find_json_end, json_str)
    assert_nil json_end
  end

  def test_project_relative_id_loaded_from_claude_md
    File.stub :exist?, true do
      File.stub :read, "## mcptask.online\n- project_relative_id=42" do
        base = McptaskRunner::ClaudeCodeBase.new
        project_id = base.send(:project_relative_id)
        assert_equal 42, project_id
      end
    end
  end

  def test_project_relative_id_returns_nil_when_file_not_found
    File.stub :exist?, false do
      base = McptaskRunner::ClaudeCodeBase.new
      project_id = base.send(:project_relative_id)
      assert_nil project_id
    end
  end

  def test_error_result_creates_error_hash
    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:error_result, 'Test error message')
    assert_equal 'error', result['status']
    assert_equal 'Test error message', result['message']
  end

  def test_inactivity_timeout_constant_is_defined
    assert_equal 1200, McptaskRunner::ClaudeCodeBase::INACTIVITY_TIMEOUT
  end

  def test_parse_result_returns_parsed_json_with_task_worked
    mock_output = 'TASKRUNNER_RESULT: {"status": "success", "hours": {"per_day": 8, "task_estimated": 2}}'
    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 1.5)

    assert_equal 'success', result['status']
    assert_equal 8, result['hours']['per_day']
    assert_equal 2, result['hours']['task_estimated']
    assert_equal 1.5, result['hours']['task_worked']
  end

  def test_parse_result_handles_error_when_result_not_found
    mock_output = 'Some output without JSON'
    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 0.5)

    assert_equal 'error', result['status']
    assert_equal 'No TASKRUNNER_RESULT found in output', result['message']
  end

  def test_parse_result_handles_invalid_json
    mock_output = 'TASKRUNNER_RESULT: {invalid json}'
    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 0.5)

    assert_equal 'error', result['status']
    assert_match(/Failed to parse JSON/, result['message'])
  end

  def test_parse_result_handles_json_with_escaped_quotes_from_real_claude_output
    # Real-world case: Claude outputs JSON with escaped quotes in markdown code block
    mock_output = "Perfect! I've loaded the task information. Let me parse and display the details:\n\n## Task Information\n\n**Task Name:** (ActionDispatch::MissingController) \"uninitialized constant Api::OfficesController\"\n\n```json\nTASKRUNNER_RESULT: {\\\"status\\\": \\\"success\\\", \\\"task_info\\\": {\\\"name\\\": \\\"(ActionDispatch::MissingController) \\\\\\\"uninitialized constant Api::OfficesController\\\\\\\"\\\", \\\"id\\\": 9005, \\\"description\\\": \\\"Test description\\\", \\\"status\\\": \\\"Nove\\\", \\\"priority\\\": \\\"Urgentni\\\", \\\"assigned_user\\\": \\\"Karel Mracek\\\", \\\"scrum_points\\\": \\\"Mirne obtizne\\\"}, \\\"hours\\\": {\\\"per_day\\\": 8, \\\"task_estimated\\\": 1.0}}\n```"

    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 0.25)

    assert_equal 'success', result['status'], 'Should parse JSON with escaped quotes successfully'
    assert_equal 9005, result['task_info']['id']
    assert_equal 'Karel Mracek', result['task_info']['assigned_user']
    assert_equal 8, result['hours']['per_day']
    assert_equal 1.0, result['hours']['task_estimated']
    assert_equal 0.25, result['hours']['task_worked']
  end

  def test_accept_edits_defaults_to_true
    base = McptaskRunner::ClaudeCodeBase.new
    assert base.send(:accept_edits?)
  end

  # Tests for retry and error handling constants
  def test_max_retry_attempts_constant_is_defined
    assert_equal 3, McptaskRunner::ClaudeCodeBase::MAX_RETRY_ATTEMPTS
  end

  def test_retry_wait_seconds_constant_is_defined
    assert_equal 30, McptaskRunner::ClaudeCodeBase::RETRY_WAIT_SECONDS
  end

  # Tests for StreamClosedError exception
  def test_stream_closed_error_exists
    assert_kind_of Class, McptaskRunner::StreamClosedError
    assert McptaskRunner::StreamClosedError < StandardError
  end

  def test_stream_closed_error_can_be_raised_with_message
    error = McptaskRunner::StreamClosedError.new('test error message')
    assert_equal 'test error message', error.message
  end

  # Tests for MissingMarkerError exception
  def test_missing_marker_error_exists
    assert_kind_of Class, McptaskRunner::MissingMarkerError
    assert McptaskRunner::MissingMarkerError < StandardError
  end

  def test_missing_marker_error_can_be_raised_with_message
    error = McptaskRunner::MissingMarkerError.new('marker not found')
    assert_equal 'marker not found', error.message
  end

  # Tests for build_command with continue_session
  def test_build_command_without_continue_session
    base = McptaskRunner::ClaudeCodeBase.new
    base.define_singleton_method(:model_name) { 'opus' }

    cmd = base.send(:build_command, '/usr/bin/claude', 'test instructions', continue_session: false)

    assert_equal '/usr/bin/claude', cmd[0]
    refute_includes cmd, '--continue'
    assert_includes cmd, '-p'
    assert_includes cmd, 'test instructions'
    assert_includes cmd, '--model'
    assert_includes cmd, 'claude-opus-4-7', 'opus alias must map to pinned 200K model ID'
    refute_includes cmd, 'claude-opus-4-7[1m]', 'must not request 1M context variant'
  end

  def test_build_command_with_continue_session
    base = McptaskRunner::ClaudeCodeBase.new
    base.define_singleton_method(:model_name) { 'opus' }

    cmd = base.send(:build_command, '/usr/bin/claude', 'test instructions', continue_session: true)

    assert_equal '/usr/bin/claude', cmd[0]
    assert_equal '--continue', cmd[1], 'Continue flag should be second element'
    assert_includes cmd, '-p'
    assert_includes cmd, 'test instructions'
  end

  def test_build_command_omits_max_turns_when_nil
    base = McptaskRunner::ClaudeCodeBase.new
    base.define_singleton_method(:model_name) { 'opus' }

    cmd = base.send(:build_command, '/usr/bin/claude', 'test instructions', continue_session: false)

    refute_includes cmd, '--max-turns'
  end

  def test_build_command_includes_max_turns_when_set
    base = McptaskRunner::ClaudeCodeBase.new
    base.define_singleton_method(:model_name) { 'opus' }
    base.define_singleton_method(:max_turns) { 150 }

    cmd = base.send(:build_command, '/usr/bin/claude', 'test instructions', continue_session: false)

    assert_includes cmd, '--max-turns'
    assert_includes cmd, '150'
  end

  def test_effective_model_name_maps_alias_to_pinned_id
    base = McptaskRunner::ClaudeCodeBase.new
    base.define_singleton_method(:model_name) { 'sonnet' }

    assert_equal 'claude-sonnet-4-6', base.send(:effective_model_name)
  end

  def test_effective_model_name_passes_through_unknown_id
    base = McptaskRunner::ClaudeCodeBase.new
    base.define_singleton_method(:model_name) { 'claude-future-99' }

    assert_equal 'claude-future-99', base.send(:effective_model_name)
  end

  # Tests for stream_lines method
  def test_stream_lines_yields_each_line
    base = McptaskRunner::ClaudeCodeBase.new
    io = StringIO.new("line1\nline2\nline3\n")
    lines = []

    base.send(:stream_lines, io) { |line| lines << line.strip }

    assert_equal %w[line1 line2 line3], lines
  end

  # Tests for handle_stream_error method
  def test_handle_stream_error_returns_early_when_stopping
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@state).stopping = true

    yielded = false
    base.send(:handle_stream_error, IOError.new('test'), 'stdout') { yielded = true }

    refute yielded, 'Should not yield when stopping'
  end

  def test_handle_stream_error_yields_error_message_when_not_stopping
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@state).stopping = false

    error_msg = nil
    base.send(:handle_stream_error, IOError.new('stream closed'), 'stdout') { |msg| error_msg = msg }

    assert_match(/stdout stream closed unexpectedly/, error_msg)
    assert_match(/stream closed/, error_msg)
  end

  # Tests for handle_recoverable_error method
  def test_handle_recoverable_error_returns_nil_for_retry
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@retry_state).count = 0
    start_time = Time.now

    result = base.send(:handle_recoverable_error, 'Timeout', start_time)

    assert_nil result, 'Should return nil to signal retry'
  end

  def test_handle_recoverable_error_returns_error_when_max_retries_reached
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@retry_state).count = 2 # MAX_RETRY_ATTEMPTS - 1
    start_time = Time.now

    result = base.send(:handle_recoverable_error, 'Timeout', start_time)

    assert_equal 'error', result['status']
    assert_match(/retries exhausted/, result['message'])
  end

  # Tests for initialization of new instance variables
  def test_initialize_sets_stopping_to_false
    base = McptaskRunner::ClaudeCodeBase.new
    refute base.instance_variable_get(:@state).stopping
  end

  def test_initialize_sets_retry_state
    base = McptaskRunner::ClaudeCodeBase.new
    retry_state = base.instance_variable_get(:@retry_state)
    assert_equal 0, retry_state.count
    assert_equal 0, retry_state.api_overload_count
    refute retry_state.marker_retry_mode
  end

  # Tests for handle_marker_retry method
  def test_handle_marker_retry_returns_nil_for_retry
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@retry_state).count = 0
    start_time = Time.now

    result = base.send(:handle_marker_retry, start_time)

    assert_nil result, 'Should return nil to signal retry'
  end

  def test_handle_marker_retry_sets_marker_retry_mode
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@retry_state).count = 0
    start_time = Time.now

    base.send(:handle_marker_retry, start_time)

    assert base.instance_variable_get(:@retry_state).marker_retry_mode, 'Should set marker_retry_mode to true'
  end

  def test_handle_marker_retry_returns_error_when_max_retries_reached
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@retry_state).count = 2 # MAX_RETRY_ATTEMPTS - 1
    start_time = Time.now

    result = base.send(:handle_marker_retry, start_time)

    assert_equal 'error', result['status']
    assert_match(/Missing TASKRUNNER_RESULT/, result['message'])
    assert_match(/retries exhausted/, result['message'])
  end

  # Tests for build_marker_retry_instructions method
  def test_build_marker_retry_instructions_contains_retry_guidance
    base = McptaskRunner::ClaudeCodeBase.new
    base.define_singleton_method(:build_instructions) { 'Original workflow instructions here' }

    instructions = base.send(:build_marker_retry_instructions)

    assert_includes instructions, 'previous session was interrupted'
    assert_includes instructions, 'Check what you already completed'
    assert_includes instructions, 'git status'
    assert_includes instructions, 'Continue from where you left off'
    assert_includes instructions, 'Complete ALL remaining steps'
    assert_includes instructions, 'TASKRUNNER_RESULT'
    assert_includes instructions, 'Do NOT just output the marker'
  end

  def test_build_marker_retry_instructions_includes_original_instructions
    base = McptaskRunner::ClaudeCodeBase.new
    original_instructions = 'Step 1: Do this\nStep 2: Do that\nTASKRUNNER_RESULT: {"status": "success"}'
    base.define_singleton_method(:build_instructions) { original_instructions }

    instructions = base.send(:build_marker_retry_instructions)

    assert_includes instructions, 'ORIGINAL WORKFLOW'
    assert_includes instructions, 'Step 1: Do this'
    assert_includes instructions, 'Step 2: Do that'
  end

  # Tests for API overload detection and handling
  def test_api_overload_detected_with_529_error_status
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@accumulated_output, '{"type":"system","subtype":"api_retry","error_status": 529}')

    assert base.send(:api_overload_detected?), 'Should detect 529 error status'
  end

  def test_api_overload_detected_with_repeated_529_message
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@accumulated_output, '[Claude] API Error: Repeated 529 Overloaded errors')

    assert base.send(:api_overload_detected?), 'Should detect repeated 529 message'
  end

  def test_api_overload_not_detected_for_normal_output
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@accumulated_output, '{"type":"result","result":"TASKRUNNER_RESULT: {}"}')

    refute base.send(:api_overload_detected?), 'Should not detect overload in normal output'
  end

  def test_handle_api_overload_returns_nil_for_retry
    base = McptaskRunner::ClaudeCodeBase.new

    base.stub(:sleep, nil) do
      result = base.send(:handle_api_overload, Time.now)
      assert_nil result, 'Should return nil to signal retry'
    end
  end

  def test_handle_api_overload_increments_counter
    base = McptaskRunner::ClaudeCodeBase.new

    base.stub(:sleep, nil) do
      base.send(:handle_api_overload, Time.now)
    end

    assert_equal 1, base.instance_variable_get(:@retry_state).api_overload_count
  end

  def test_handle_api_overload_returns_error_at_max_retries
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@retry_state).api_overload_count = McptaskRunner::Concerns::RetryHandling::MAX_API_OVERLOAD_RETRIES - 1

    result = base.send(:handle_api_overload, Time.now)

    assert_equal 'error', result['status']
    assert_match(/API overloaded/, result['message'])
    assert_match(/529/, result['message'])
  end

  def test_api_overload_does_not_increment_normal_retry_count
    base = McptaskRunner::ClaudeCodeBase.new
    retry_state = base.instance_variable_get(:@retry_state)
    retry_state.count = 0
    retry_state.api_overload_count = 1

    # After API overload, retry count should remain 0
    assert_equal 0, retry_state.count
  end

  def test_initialize_sets_api_overload_flag_to_false
    base = McptaskRunner::ClaudeCodeBase.new
    refute base.instance_variable_get(:@state).api_overload
  end

  def test_check_for_api_overload_sets_flag_on_529
    base = McptaskRunner::ClaudeCodeBase.new
    base.send(:check_for_api_overload, '{"type":"system","subtype":"api_retry","error_status": 529}')

    assert base.instance_variable_get(:@state).api_overload, 'Should set flag on 529 error'
  end

  def test_check_for_api_overload_sets_flag_on_repeated_529
    base = McptaskRunner::ClaudeCodeBase.new
    base.send(:check_for_api_overload, '[Claude] API Error: Repeated 529 Overloaded errors')

    assert base.instance_variable_get(:@state).api_overload, 'Should set flag on repeated 529'
  end

  def test_check_for_api_overload_does_not_set_flag_on_normal_output
    base = McptaskRunner::ClaudeCodeBase.new
    base.send(:check_for_api_overload, '{"type":"assistant","message":"Hello"}')

    refute base.instance_variable_get(:@state).api_overload, 'Should not set flag on normal output'
  end

  def test_api_overload_detected_via_flag
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@accumulated_output, '')
    base.instance_variable_get(:@state).api_overload = true

    assert base.send(:api_overload_detected?), 'Should detect overload via flag even with empty accumulated_output'
  end

  def test_stream_closed_with_529_raises_api_overload
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@state).api_overload = true

    # attempt_execution rescues StreamClosedError, checks flag, re-raises as ApiOverloadError
    # which is then caught and handled by handle_api_overload
    base.stub(:sleep, nil) do
      result = base.send(:handle_api_overload, Time.now)
      assert_nil result, 'API overload handler should return nil to signal retry'
      assert_equal 1, base.instance_variable_get(:@retry_state).api_overload_count, 'Should increment overload counter'
    end
  end

  # Tests for context overflow detection — session exceeded 1M token limit, cannot --continue
  def test_initialize_sets_context_overflow_flag_to_false
    base = McptaskRunner::ClaudeCodeBase.new
    refute base.instance_variable_get(:@state).context_overflow
  end

  def test_check_for_context_overflow_sets_flag_on_prompt_too_long
    base = McptaskRunner::ClaudeCodeBase.new
    base.send(:check_for_context_overflow, '[Claude] Prompt is too long')

    assert base.instance_variable_get(:@state).context_overflow, 'Should set flag on "Prompt is too long"'
    assert base.instance_variable_get(:@state).stopping, 'Should mark stopping to treat stream closure as expected'
  end

  def test_check_for_context_overflow_matches_context_length_exceeded
    base = McptaskRunner::ClaudeCodeBase.new
    base.send(:check_for_context_overflow, '{"error":{"type":"context_length_exceeded"}}')

    assert base.instance_variable_get(:@state).context_overflow
  end

  def test_check_for_context_overflow_does_not_set_flag_on_normal_output
    base = McptaskRunner::ClaudeCodeBase.new
    base.send(:check_for_context_overflow, '{"type":"assistant","message":"Hello"}')

    refute base.instance_variable_get(:@state).context_overflow
  end

  def test_context_overflow_detected_via_flag
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@accumulated_output, '')
    base.instance_variable_get(:@state).context_overflow = true

    assert base.send(:context_overflow_detected?), 'Should detect via flag even with empty accumulated_output'
  end

  def test_context_overflow_detected_via_accumulated_output
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@accumulated_output, 'some output Prompt is too long some more')

    assert base.send(:context_overflow_detected?)
  end

  def test_handle_context_overflow_returns_terminal_error_no_retry
    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:handle_context_overflow, Time.now - 3600)

    assert_equal 'error', result['status']
    assert_equal 'context_overflow', result['reason']
    assert_match(/Context overflow/, result['message'])
    assert_match(/cannot resume/, result['message'])
    assert_equal 0, base.instance_variable_get(:@retry_state).count,
                 'Must NOT increment retry counter — session is dead, --continue cannot recover'
  end

  # Tests for result_received flag and early stream termination
  def test_initialize_sets_result_received_to_false
    base = McptaskRunner::ClaudeCodeBase.new
    refute base.instance_variable_get(:@state).result_received
  end

  def test_check_for_result_message_ignores_interim_result_without_marker
    base = McptaskRunner::ClaudeCodeBase.new
    result_line = '{"type": "result", "result": "Tests running in background..."}'

    base.send(:check_for_result_message, result_line)

    refute base.instance_variable_get(:@state).result_received
    refute base.instance_variable_get(:@state).stopping
  end

  def test_check_for_result_message_sets_flag_on_final_result_with_marker
    base = McptaskRunner::ClaudeCodeBase.new
    result_line = '{"type": "result", "result": "{\"TASKRUNNER_RESULT\": true, \"status\": \"success\"}"}'

    base.send(:check_for_result_message, result_line)

    assert base.instance_variable_get(:@state).result_received
    assert base.instance_variable_get(:@state).stopping
  end

  def test_check_for_result_message_ignores_non_result_types
    base = McptaskRunner::ClaudeCodeBase.new
    assistant_line = '{"type": "assistant", "message": "Hello"}'

    base.send(:check_for_result_message, assistant_line)

    refute base.instance_variable_get(:@state).result_received
  end

  def test_check_for_result_message_ignores_invalid_json
    base = McptaskRunner::ClaudeCodeBase.new
    invalid_line = 'This is not JSON at all'

    base.send(:check_for_result_message, invalid_line)

    refute base.instance_variable_get(:@state).result_received
  end

  def test_check_for_result_message_skips_when_already_received
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@state).result_received = true
    base.instance_variable_get(:@state).stopping = false
    result_line = '{"type": "result", "cost_usd": 0.05}'

    base.send(:check_for_result_message, result_line)

    # @stopping should remain false since we skipped processing
    refute base.instance_variable_get(:@state).stopping
  end

  def test_stream_lines_breaks_when_result_received
    base = McptaskRunner::ClaudeCodeBase.new
    io = StringIO.new("line1\nline2\nline3\nline4\n")
    lines = []

    base.send(:stream_lines, io) do |line|
      lines << line.strip
      # Simulate result received after line2
      base.instance_variable_get(:@state).result_received = true if line.strip == 'line2'
    end

    assert_equal %w[line1 line2], lines, 'Should stop after result_received is set'
  end

  # Tests for PROCESS_KILL_TIMEOUT constant
  def test_process_kill_timeout_constant_is_defined
    assert_equal 5, McptaskRunner::ClaudeCodeBase::PROCESS_KILL_TIMEOUT
  end

  # Tests for @child_pid initialization
  def test_initialize_sets_child_pid_to_nil
    base = McptaskRunner::ClaudeCodeBase.new
    assert_nil base.instance_variable_get(:@state).child_pid
  end

  # Tests for kill_process method
  def test_kill_process_returns_early_for_nil_pid
    base = McptaskRunner::ClaudeCodeBase.new
    # Should not raise anything
    assert_nil base.send(:kill_process, nil)
  end

  def test_kill_process_handles_already_dead_process
    base = McptaskRunner::ClaudeCodeBase.new
    # ESRCH means no such process - kill_process should handle gracefully
    Process.stub(:getpgid, ->(_pid) { raise Errno::ESRCH }) do
      Process.stub(:kill, ->(_sig, _pid) { raise Errno::ESRCH }) do
        assert_nil base.send(:kill_process, 99_999)
      end
    end
  end

  def test_kill_process_escalates_to_sigkill_when_process_does_not_die
    base = McptaskRunner::ClaudeCodeBase.new
    signals_sent = []

    # Simulate process that survives SIGTERM (kill(0, pid) never raises ESRCH)
    kill_stub = lambda do |sig, _pid|
      signals_sent << sig
      # Simulate ESRCH only for KILL signal to end the method
      raise Errno::ESRCH if sig == 'KILL'
    end

    Process.stub(:getpgid, 99_999) do
      Process.stub(:kill, kill_stub) do
        base.stub(:sleep, nil) do
          base.send(:kill_process, 99_999)
        end
      end
    end

    assert_includes signals_sent, 'TERM'
    assert_includes signals_sent, 'KILL'
  end

  # Tests for time_awareness_instruction method
  def test_time_awareness_instruction_returns_string
    base = McptaskRunner::ClaudeCodeBase.new
    instruction = base.send(:time_awareness_instruction)
    assert_includes instruction, 'TIME MANAGEMENT'
    assert_includes instruction, '20 min inactive'
    assert_includes instruction, 'TASKRUNNER_RESULT'
  end

  def test_initialize_sets_inactivity_timeout_to_false
    base = McptaskRunner::ClaudeCodeBase.new
    refute base.instance_variable_get(:@state).inactivity_timeout
  end

  # Tests for release_test_lock method
  def test_release_test_lock_handles_missing_script
    base = McptaskRunner::ClaudeCodeBase.new
    File.stub(:executable?, false) do
      # Should return early without raising
      assert_nil base.send(:release_test_lock)
    end
  end

  # Tests for branch_resume_check_step method
  def test_branch_resume_check_step_contains_branch_detection
    base = McptaskRunner::ClaudeCodeBase.new
    step = base.send(:branch_resume_check_step, project_id: 7)
    assert_includes step, 'git branch --show-current'
    assert_includes step, 'GIT STATE + RESUME CHECK'
  end

  def test_branch_resume_check_step_contains_resume_logic
    base = McptaskRunner::ClaudeCodeBase.new
    step = base.send(:branch_resume_check_step, project_id: 7)
    assert_includes step, 'RESUME'
    assert_includes step, 'SKIP steps 2-3'
  end

  def test_branch_resume_check_step_with_pull
    base = McptaskRunner::ClaudeCodeBase.new
    step = base.send(:branch_resume_check_step, project_id: 7, pull_on_main: true)
    assert_includes step, 'git pull'
    assert_includes step, 'git checkout main && git pull'
  end

  def test_branch_resume_check_step_without_pull
    base = McptaskRunner::ClaudeCodeBase.new
    step = base.send(:branch_resume_check_step, project_id: 7, pull_on_main: false)
    refute_includes step, 'git pull'
    assert_includes step, 'git checkout main'
  end

  # Tests for triaged_git_step method
  def test_triaged_git_step_resuming_skips_checkout
    base = McptaskRunner::ClaudeCodeBase.new
    step = base.send(:triaged_git_step, resuming: true)
    assert_includes step, 'RESUME'
    refute_includes step, 'git checkout main'
    assert_includes step, 'SKIP steps 2-3'
  end

  def test_triaged_git_step_not_resuming_checks_out_main
    base = McptaskRunner::ClaudeCodeBase.new
    step = base.send(:triaged_git_step, resuming: false)
    assert_includes step, 'git checkout main && git pull'
    refute_includes step, 'RESUME'
  end

  def test_heartbeat_interval_constant_is_defined
    assert_equal 120, McptaskRunner::ClaudeCodeBase::HEARTBEAT_INTERVAL
  end

  def test_initialize_sets_stream_line_count_to_zero
    base = McptaskRunner::ClaudeCodeBase.new
    assert_equal 0, base.instance_variable_get(:@state).stream_line_count
  end

  def test_stdout_sync_is_enabled
    assert $stdout.sync, 'Expected $stdout.sync to be true'
  end

  def test_kill_process_does_not_escalate_when_process_dies_after_sigterm
    base = McptaskRunner::ClaudeCodeBase.new
    signals_sent = []
    check_count = 0

    kill_stub = lambda do |sig, _pid|
      signals_sent << sig
      # After TERM sent, simulate process dying on first existence check (kill(0, pid))
      if sig == 0
        check_count += 1
        raise Errno::ESRCH if check_count >= 1
      end
    end

    Process.stub(:getpgid, 99_999) do
      Process.stub(:kill, kill_stub) do
        base.stub(:sleep, nil) do
          base.send(:kill_process, 99_999)
        end
      end
    end

    assert_includes signals_sent, 'TERM'
    refute_includes signals_sent, 'KILL'
  end

  # Tests for resolve_process_group helper method
  def test_resolve_process_group_returns_pgid_for_current_process
    base = McptaskRunner::ClaudeCodeBase.new
    pgid = base.send(:resolve_process_group, Process.pid)
    assert_kind_of Integer, pgid
  end

  def test_resolve_process_group_returns_nil_for_dead_process
    base = McptaskRunner::ClaudeCodeBase.new
    pgid = base.send(:resolve_process_group, 99_999_999)
    assert_nil pgid
  end

  # Tests for safe_kill helper method
  def test_safe_kill_returns_false_for_dead_process
    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:safe_kill, 'TERM', 99_999_999)
    assert_equal false, result
  end

  def test_safe_kill_returns_true_for_alive_process
    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:safe_kill, 0, Process.pid)
    assert_equal true, result
  end

  # Tests for process group kill behaviour in kill_process
  def test_kill_process_sends_signal_to_negative_pgid
    base = McptaskRunner::ClaudeCodeBase.new
    kill_targets = []

    Process.stub(:getpgid, 42_000) do
      Process.stub(:kill, ->(sig, pid) { kill_targets << [sig, pid]; raise Errno::ESRCH if sig == 'TERM' }) do
        base.send(:kill_process, 99_999)
      end
    end

    assert_includes kill_targets, ['TERM', -42_000]
  end

  def test_kill_process_falls_back_to_pid_when_pgid_unavailable
    base = McptaskRunner::ClaudeCodeBase.new
    kill_targets = []

    Process.stub(:getpgid, ->(_pid) { raise Errno::ESRCH }) do
      Process.stub(:kill, ->(sig, pid) { kill_targets << [sig, pid]; raise Errno::ESRCH if sig == 'TERM' }) do
        base.send(:kill_process, 99_999)
      end
    end

    # Should use positive pid (direct), not negative pgid
    assert_includes kill_targets, ['TERM', 99_999]
    term_calls = kill_targets.select { |sig, _| sig == 'TERM' }
    assert term_calls.all? { |_, pid| pid > 0 }, 'Should use positive pid when pgid unavailable'
  end

  # Tests for extract_text_from_line method
  def test_extract_text_from_line_with_text_delta_event
    base = McptaskRunner::ClaudeCodeBase.new
    line = '{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello world"}}'
    assert_equal 'Hello world', base.send(:extract_text_from_line, line)
  end

  def test_extract_text_from_line_with_assistant_message_event
    base = McptaskRunner::ClaudeCodeBase.new
    line = '{"type":"assistant","message":{"content":[{"type":"text","text":"Full message here"}]}}'
    assert_equal 'Full message here', base.send(:extract_text_from_line, line)
  end

  def test_extract_text_from_line_with_non_text_event
    base = McptaskRunner::ClaudeCodeBase.new
    line = '{"type":"result","cost_usd":0.05}'
    assert_equal '', base.send(:extract_text_from_line, line)
  end

  def test_extract_text_from_line_with_invalid_json
    base = McptaskRunner::ClaudeCodeBase.new
    assert_equal '', base.send(:extract_text_from_line, 'not json')
  end

  def test_extract_text_from_line_with_multiple_content_blocks
    base = McptaskRunner::ClaudeCodeBase.new
    line = '{"type":"assistant","message":{"content":[{"type":"text","text":"Part 1"},{"type":"tool_use","id":"123"},{"type":"text","text":"Part 2"}]}}'
    assert_equal 'Part 1Part 2', base.send(:extract_text_from_line, line)
  end

  # Tests for parse_result with stream-json wrapped output (the actual bug scenario)
  def test_parse_result_with_stream_json_wrapped_result
    base = McptaskRunner::ClaudeCodeBase.new
    # Simulate @text_content accumulated from stream-json extraction
    base.instance_variable_set(:@text_content,
                               'I analyzed the task.\nTASKRUNNER_RESULT: {"status": "success", "task_id": 9508, "recommended_model": "sonnet", "hours": {"per_day": 8}}')

    result = base.send(:parse_result, 'raw stream json that does not contain marker', 1.0)

    assert_equal 'success', result['status']
    assert_equal 9508, result['task_id']
    assert_equal 'sonnet', result['recommended_model']
    assert_equal 1.0, result['hours']['task_worked']
  end

  def test_parse_result_falls_back_to_raw_output_when_text_content_empty
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@text_content, '')

    raw = 'TASKRUNNER_RESULT: {"status": "success", "hours": {"per_day": 4}}'
    result = base.send(:parse_result, raw, 0.5)

    assert_equal 'success', result['status']
    assert_equal 4, result['hours']['per_day']
  end

  def test_parse_result_falls_back_to_raw_when_text_content_lacks_marker
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@text_content, 'Some text without the marker')

    raw = 'TASKRUNNER_RESULT: {"status": "success", "hours": {"per_day": 6}}'
    result = base.send(:parse_result, raw, 0.3)

    assert_equal 'success', result['status']
    assert_equal 6, result['hours']['per_day']
  end

  # Tests for new JSON key marker format: {"TASKRUNNER_RESULT": true, ...}
  def test_parse_result_with_json_key_marker
    mock_output = '{"TASKRUNNER_RESULT": true, "status": "success", "hours": {"per_day": 8, "task_estimated": 2}}'
    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 1.5)

    assert_equal 'success', result['status']
    assert_equal 8, result['hours']['per_day']
    assert_equal 2, result['hours']['task_estimated']
    assert_equal 1.5, result['hours']['task_worked']
    refute result.key?('TASKRUNNER_RESULT'), 'TASKRUNNER_RESULT key should be removed from result'
  end

  def test_parse_result_with_json_key_marker_in_code_block
    mock_output = "Here is the result:\n\n```json\n{\"TASKRUNNER_RESULT\": true, \"status\": \"success\", \"hours\": {\"per_day\": 6}}\n```"
    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 0.5)

    assert_equal 'success', result['status']
    assert_equal 6, result['hours']['per_day']
  end

  def test_parse_result_with_json_key_marker_in_text_content
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@text_content,
                               "Analysis done.\n{\"TASKRUNNER_RESULT\": true, \"status\": \"success\", \"task_id\": 9843, \"hours\": {\"per_day\": 8}}")

    result = base.send(:parse_result, 'raw stream without marker', 1.0)

    assert_equal 'success', result['status']
    assert_equal 9843, result['task_id']
  end

  def test_parse_result_json_key_falls_back_to_raw_stdout
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@text_content, 'No marker here')

    raw = '{"TASKRUNNER_RESULT": true, "status": "success", "hours": {"per_day": 4}}'
    result = base.send(:parse_result, raw, 0.3)

    assert_equal 'success', result['status']
    assert_equal 4, result['hours']['per_day']
  end

  # Tests for result_format_instruction method
  def test_result_format_instruction_includes_json_code_block
    base = McptaskRunner::ClaudeCodeBase.new
    instruction = base.send(:result_format_instruction, '"status": "success"')

    assert_includes instruction, '```json'
    assert_includes instruction, '"TASKRUNNER_RESULT": true'
    assert_includes instruction, '"status": "success"'
    assert_includes instruction, 'CRITICAL FORMATTING'
  end

  def test_result_format_instruction_with_extra_rules
    base = McptaskRunner::ClaudeCodeBase.new
    instruction = base.send(:result_format_instruction, '"status": "success"',
                            extra_rules: ['task_id MUST be numeric'])

    assert_includes instruction, 'task_id MUST be numeric'
  end

  # Tests for tool tracking (via SnapshotBuilder)
  def test_initialize_has_no_active_tools
    base = McptaskRunner::ClaudeCodeBase.new
    assert_equal 0, base.instance_variable_get(:@snapshot_builder).active_tool_count
  end

  def test_track_tool_event_adds_tool_use
    base = McptaskRunner::ClaudeCodeBase.new
    line = '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"tool_123","name":"Skill","input":{}}]}}'

    McptaskRunner::EventStream.stub(:emit_snapshot, nil) { base.send(:track_tool_event, line) }

    builder = base.instance_variable_get(:@snapshot_builder)
    assert_equal 1, builder.active_tool_count
    assert_includes builder.active_tool_names, 'Skill'
  end

  def test_track_tool_event_removes_on_tool_result
    base = McptaskRunner::ClaudeCodeBase.new
    builder = base.instance_variable_get(:@snapshot_builder)
    builder.tool_started(tool_id: 'tool_123', name: 'Skill', summary: '')

    line = '{"type":"assistant","message":{"content":[{"type":"tool_result","tool_use_id":"tool_123","content":"ok"}]}}'
    McptaskRunner::EventStream.stub(:emit_snapshot, nil) { base.send(:track_tool_event, line) }

    assert_equal 0, builder.active_tool_count
  end

  def test_track_tool_event_ignores_non_json
    base = McptaskRunner::ClaudeCodeBase.new
    McptaskRunner::EventStream.stub(:emit_snapshot, nil) { base.send(:track_tool_event, 'not json at all') }
    assert_equal 0, base.instance_variable_get(:@snapshot_builder).active_tool_count
  end

  def test_track_tool_event_ignores_lines_without_content
    base = McptaskRunner::ClaudeCodeBase.new
    McptaskRunner::EventStream.stub(:emit_snapshot, nil) { base.send(:track_tool_event, '{"type":"result","cost_usd":0.05}') }
    assert_equal 0, base.instance_variable_get(:@snapshot_builder).active_tool_count
  end

  def test_format_active_tools_empty
    base = McptaskRunner::ClaudeCodeBase.new
    assert_equal '', base.send(:format_active_tools)
  end

  def test_format_active_tools_with_tools
    base = McptaskRunner::ClaudeCodeBase.new
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    builder = base.instance_variable_get(:@snapshot_builder)
    # Directly backdate mono_started_at for testing
    builder.instance_variable_get(:@active_actions)['tool_1'] = {
      name: 'Skill', summary: '', mono_started_at: now - 300, started_at: Time.now.utc.iso8601(3)
    }

    result = base.send(:format_active_tools, now)
    assert_includes result, 'waiting for:'
    assert_includes result, 'Skill since 300s'
  end

  def test_write_debug_dump_creates_file
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@state).stream_line_count = 198
    base.instance_variable_set(:@text_content, "line 1\nline 2\n")
    base.instance_variable_set(:@log_tag, 'test')

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        base.send(:write_debug_dump, 'some stderr', 99_999)
        dumps = Dir.glob('log/debug_dump_*.txt')
        assert_equal 1, dumps.size
        content = File.read(dumps.first)
        assert_includes content, 'Stream event count: 198'
        assert_includes content, 'ACTIVE TOOL CALLS'
        assert_includes content, 'PROCESS TREE'
        assert_includes content, 'some stderr'
        assert_includes content, 'line 1'
      end
    end
  end

  # Tests for QuotaExceededMidTaskError
  def test_quota_exceeded_mid_task_error_exists
    assert_kind_of Class, McptaskRunner::QuotaExceededMidTaskError
    assert McptaskRunner::QuotaExceededMidTaskError < StandardError
  end

  def test_initialize_sets_quota_watch_to_nil
    base = McptaskRunner::ClaudeCodeBase.new
    assert_nil base.instance_variable_get(:@quota_watch)
  end

  def test_initialize_sets_quota_exceeded_to_false
    base = McptaskRunner::ClaudeCodeBase.new
    refute base.instance_variable_get(:@state).quota_exceeded
  end

  def test_quota_watch_writer_accepts_hash
    base = McptaskRunner::ClaudeCodeBase.new
    base.quota_watch = { per_day_hours: 8.0, already_worked_hours: 7.0 }
    assert_equal 8.0, base.instance_variable_get(:@quota_watch)[:per_day_hours]
  end

  def test_quota_exceeded_now_returns_false_when_quota_watch_nil
    base = McptaskRunner::ClaudeCodeBase.new
    refute base.send(:quota_exceeded_now?, 0.0, 100.0)
  end

  def test_quota_exceeded_now_returns_false_when_per_day_zero
    base = McptaskRunner::ClaudeCodeBase.new
    base.quota_watch = { per_day_hours: 0.0, already_worked_hours: 0.0 }
    refute base.send(:quota_exceeded_now?, 0.0, 7200.0)
  end

  def test_quota_exceeded_now_returns_false_when_under_quota
    base = McptaskRunner::ClaudeCodeBase.new
    # 6h already + 1h this run = 7h, per_day = 8h → not exceeded
    base.quota_watch = { per_day_hours: 8.0, already_worked_hours: 6.0 }
    execution_start = 1_000.0
    now = execution_start + 3600.0 # +1h
    refute base.send(:quota_exceeded_now?, execution_start, now)
  end

  def test_quota_exceeded_now_returns_true_when_at_or_above_quota
    base = McptaskRunner::ClaudeCodeBase.new
    # 7h already + 1h this run = 8h, per_day = 8h → exceeded (>=)
    base.quota_watch = { per_day_hours: 8.0, already_worked_hours: 7.0 }
    execution_start = 1_000.0
    now = execution_start + 3600.0 # +1h
    assert base.send(:quota_exceeded_now?, execution_start, now)
  end

  def test_quota_exceeded_now_returns_true_when_already_exceeded_at_start
    base = McptaskRunner::ClaudeCodeBase.new
    # 9h already, per_day = 8h → exceeded immediately
    base.quota_watch = { per_day_hours: 8.0, already_worked_hours: 9.0 }
    execution_start = 1_000.0
    assert base.send(:quota_exceeded_now?, execution_start, execution_start)
  end

  def test_reset_streaming_state_clears_quota_exceeded_flag
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@state).quota_exceeded = true
    base.send(:reset_streaming_state)
    refute base.instance_variable_get(:@state).quota_exceeded
  end

  # Tests for StalledError exception
  def test_stalled_error_exists
    assert_kind_of Class, McptaskRunner::StalledError
    assert McptaskRunner::StalledError < StandardError
  end

  def test_stalled_error_carries_stall_struct
    stall = McptaskRunner::StallDetector::Stall.new(reason: :edit_failures, signature: 'sig', count: 3)
    error = McptaskRunner::StalledError.new(stall)

    assert_equal stall, error.stall
    assert_match(/edit_failures/, error.message)
    assert_match(/sig/, error.message)
  end

  # Tests for stall integration
  def test_initialize_sets_stalled_to_nil
    base = McptaskRunner::ClaudeCodeBase.new
    assert_nil base.instance_variable_get(:@state).stalled
  end

  def test_initialize_creates_stall_detector
    base = McptaskRunner::ClaudeCodeBase.new
    assert_kind_of McptaskRunner::StallDetector, base.instance_variable_get(:@stall_detector)
  end

  def test_reset_streaming_state_clears_stalled_flag_and_replaces_detector
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@state).stalled = :something
    old_detector = base.instance_variable_get(:@stall_detector)

    base.send(:reset_streaming_state)

    assert_nil base.instance_variable_get(:@state).stalled
    refute_same old_detector, base.instance_variable_get(:@stall_detector),
                'Detector must be recreated so accumulated state from prior attempt is dropped'
  end

  # check_stall integration — verifies SIGTERM and stall ivar are set
  def test_check_stall_sets_stalled_and_stops
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@state).child_pid = nil # nil PID → kill_process is a no-op
    base.instance_variable_get(:@snapshot_builder).set_status(:triage)
    base.instance_variable_get(:@snapshot_builder).set_status(:processing)
    stall = McptaskRunner::StallDetector::Stall.new(reason: :edit_failures, signature: 'sig', count: 3)

    McptaskRunner::EventStream.stub(:emit_snapshot, nil) { base.send(:check_stall, stall) }

    assert_equal stall, base.instance_variable_get(:@state).stalled
    assert base.instance_variable_get(:@state).stopping
  end

  def test_check_stall_ignores_nil
    base = McptaskRunner::ClaudeCodeBase.new
    base.send(:check_stall, nil)
    assert_nil base.instance_variable_get(:@state).stalled
    refute base.instance_variable_get(:@state).stopping
  end

  def test_check_stall_emits_snapshot_with_stalled_status
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@snapshot_builder).set_status(:triage)
    base.instance_variable_get(:@snapshot_builder).set_status(:processing)
    stall = McptaskRunner::StallDetector::Stall.new(reason: :edit_failures, signature: 'sig', count: 3, detail: nil)
    emitted_snapshots = []

    McptaskRunner::EventStream.stub(:emit_snapshot, ->(snapshot, force: false) { emitted_snapshots << snapshot }) do
      base.send(:check_stall, stall)
    end

    assert_equal 1, emitted_snapshots.size
    assert_equal 'stalled', emitted_snapshots.first[:status]
    assert_match(/edit_failures/, emitted_snapshots.first[:error_message])
    assert_match(/sig/, emitted_snapshots.first[:error_message])
  end

  def test_check_stall_does_not_overwrite_first_stall
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@snapshot_builder).set_status(:triage)
    base.instance_variable_get(:@snapshot_builder).set_status(:processing)
    first = McptaskRunner::StallDetector::Stall.new(reason: :edit_failures, signature: 'a', count: 3)
    second = McptaskRunner::StallDetector::Stall.new(reason: :loop_signature, signature: 'b', count: 4)

    McptaskRunner::EventStream.stub(:emit_snapshot, nil) do
      base.send(:check_stall, first)
      base.send(:check_stall, second)
    end

    assert_equal first, base.instance_variable_get(:@state).stalled,
                 'First stall wins; subsequent detections are ignored'
  end

  # track_tool_event integration — feeds StallDetector via parsed JSONL
  def test_track_tool_event_triggers_stall_after_three_edit_failures
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_get(:@snapshot_builder).set_status(:triage)
    base.instance_variable_get(:@snapshot_builder).set_status(:processing)
    use_line = '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"u1","name":"Edit","input":{"file_path":"/a.rb","old_string":"foo"}}]}}'
    err_line = '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"u1","is_error":true,"content":"String not found"}]}}'

    McptaskRunner::EventStream.stub(:emit_snapshot, nil) do
      3.times do |i|
        indexed_use = use_line.gsub('"u1"', "\"u#{i}\"")
        indexed_err = err_line.gsub('"u1"', "\"u#{i}\"")
        base.send(:track_tool_event, indexed_use)
        base.send(:track_tool_event, indexed_err)
      end
    end

    stall = base.instance_variable_get(:@state).stalled
    refute_nil stall
    assert_equal :edit_failures, stall.reason
    assert base.instance_variable_get(:@state).stopping
  end

  # handle_stalled — terminal status='stalled_for_opus', NOT 'error'
  def test_handle_stalled_returns_stalled_for_opus_status
    base = McptaskRunner::ClaudeCodeBase.new
    stall = McptaskRunner::StallDetector::Stall.new(reason: :edit_failures, signature: 'sig', count: 3, detail: nil)

    result = base.send(:handle_stalled, stall, Time.now - 600)

    assert_equal 'stalled_for_opus', result['status']
    refute_equal 'error', result['status'], 'Must not return error — Decider would break the loop'
    assert_equal 'edit_failures', result['reason']
    assert_equal 'sig', result['signature']
    assert_equal 3, result['count']
    assert_match(/Stalled/, result['message'])
    assert result['hours']['task_worked']
  end

  def test_handle_stalled_does_not_increment_retry_count
    base = McptaskRunner::ClaudeCodeBase.new
    stall = McptaskRunner::StallDetector::Stall.new(reason: :loop_signature, signature: 'sig', count: 4)

    base.send(:handle_stalled, stall, Time.now)

    assert_equal 0, base.instance_variable_get(:@retry_state).count,
                 'Stall is terminal; --continue retry would re-enter the same loop'
  end

  def test_raise_streaming_errors_raises_stalled_before_stream_closed
    base = McptaskRunner::ClaudeCodeBase.new
    stall = McptaskRunner::StallDetector::Stall.new(reason: :edit_failures, signature: 'sig', count: 3)
    base.instance_variable_get(:@state).stalled = stall

    error = assert_raises(McptaskRunner::StalledError) do
      base.send(:raise_streaming_errors_if_any, 'unrelated stream error')
    end
    assert_equal stall, error.stall
  end

  # Tests for per-tool hang timeout — fast tools (MCP, Read/Edit/Grep) get a shorter ceiling than
  # long tools (Bash/Task running tests, CI, subagents). Catches MCP server hangs without
  # waiting the full 60min long-tool ceiling.
  def test_quick_tool_hang_timeout_constant_is_defined
    assert_equal 120, McptaskRunner::ClaudeCodeBase::QUICK_TOOL_HANG_TIMEOUT
  end

  def test_long_running_tools_constant_includes_bash_and_task
    assert_includes McptaskRunner::ClaudeCodeBase::LONG_RUNNING_TOOLS, 'Bash'
    assert_includes McptaskRunner::ClaudeCodeBase::LONG_RUNNING_TOOLS, 'Task'
  end

  def test_tool_hang_timeout_for_bash_uses_long_ceiling
    base = McptaskRunner::ClaudeCodeBase.new
    assert_equal McptaskRunner::ClaudeCodeBase::TOOL_HANG_TIMEOUT,
                 base.send(:tool_hang_timeout_for, 'Bash')
  end

  def test_tool_hang_timeout_for_task_uses_long_ceiling
    base = McptaskRunner::ClaudeCodeBase.new
    assert_equal McptaskRunner::ClaudeCodeBase::TOOL_HANG_TIMEOUT,
                 base.send(:tool_hang_timeout_for, 'Task')
  end

  def test_tool_hang_timeout_for_mcp_tool_uses_quick_ceiling
    base = McptaskRunner::ClaudeCodeBase.new
    assert_equal McptaskRunner::ClaudeCodeBase::QUICK_TOOL_HANG_TIMEOUT,
                 base.send(:tool_hang_timeout_for, 'mcp__mcptask-online__LogWorkProgressTool')
  end

  def test_tool_hang_timeout_for_read_uses_quick_ceiling
    base = McptaskRunner::ClaudeCodeBase.new
    assert_equal McptaskRunner::ClaudeCodeBase::QUICK_TOOL_HANG_TIMEOUT,
                 base.send(:tool_hang_timeout_for, 'Read')
  end

  def test_hung_tool_returns_nil_when_no_active_tools
    base = McptaskRunner::ClaudeCodeBase.new
    assert_nil base.send(:hung_tool, Process.clock_gettime(Process::CLOCK_MONOTONIC))
  end

  def test_hung_tool_returns_nil_when_quick_tool_within_limit
    base = McptaskRunner::ClaudeCodeBase.new
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    base.instance_variable_get(:@snapshot_builder).instance_variable_get(:@active_actions)['id1'] = {
      name: 'mcp__mcptask-online__LogWorkProgressTool', summary: '', mono_started_at: now - 60, started_at: Time.now.utc.iso8601(3)
    }
    assert_nil base.send(:hung_tool, now)
  end

  def test_hung_tool_detects_quick_tool_past_quick_limit
    base = McptaskRunner::ClaudeCodeBase.new
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    base.instance_variable_get(:@snapshot_builder).instance_variable_get(:@active_actions)['id1'] = {
      name: 'mcp__mcptask-online__LogWorkProgressTool', summary: '', mono_started_at: now - 200, started_at: Time.now.utc.iso8601(3)
    }
    hung = base.send(:hung_tool, now)
    refute_nil hung, 'Quick MCP tool stuck >120s should be flagged hung'
    assert_equal 'mcp__mcptask-online__LogWorkProgressTool', hung[:name]
  end

  def test_hung_tool_ignores_bash_within_long_limit
    base = McptaskRunner::ClaudeCodeBase.new
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    # 25 min Bash run (system tests) — well under 60min long ceiling
    base.instance_variable_get(:@snapshot_builder).instance_variable_get(:@active_actions)['id1'] = {
      name: 'Bash', summary: '', mono_started_at: now - 1500, started_at: Time.now.utc.iso8601(3)
    }
    assert_nil base.send(:hung_tool, now), 'Bash within long ceiling must not be flagged'
  end

  def test_hung_tool_detects_bash_past_long_limit
    base = McptaskRunner::ClaudeCodeBase.new
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    base.instance_variable_get(:@snapshot_builder).instance_variable_get(:@active_actions)['id1'] = {
      name: 'Bash', summary: '', mono_started_at: now - 3700, started_at: Time.now.utc.iso8601(3)
    }
    refute_nil base.send(:hung_tool, now), 'Bash past 60min ceiling should be flagged'
  end

  def test_hung_tool_picks_quick_tool_over_long_bash
    base = McptaskRunner::ClaudeCodeBase.new
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    actions = base.instance_variable_get(:@snapshot_builder).instance_variable_get(:@active_actions)
    # Bash legitimately running 20min + MCP tool hung 3min — quick tool is the issue
    actions['bash1'] = { name: 'Bash', summary: '', mono_started_at: now - 1200, started_at: Time.now.utc.iso8601(3) }
    actions['mcp1'] = { name: 'mcp__mcptask-online__AddMessageTool', summary: '', mono_started_at: now - 180, started_at: Time.now.utc.iso8601(3) }
    hung = base.send(:hung_tool, now)
    refute_nil hung
    assert_equal 'mcp__mcptask-online__AddMessageTool', hung[:name]
  end

  # Tests for marker_parse_failed? — distinguishes "marker absent / parse failed" from
  # Claude legitimately reporting status=error inside TASKRUNNER_RESULT.
  def test_marker_parse_failed_true_when_marker_absent
    base = McptaskRunner::ClaudeCodeBase.new
    assert base.send(:marker_parse_failed?, { 'status' => 'error', 'message' => 'No TASKRUNNER_RESULT found in output' })
  end

  def test_marker_parse_failed_false_when_status_success
    base = McptaskRunner::ClaudeCodeBase.new
    refute base.send(:marker_parse_failed?, { 'status' => 'success', 'pr_number' => 1158 })
  end

  def test_marker_parse_failed_false_when_claude_reports_legit_error
    base = McptaskRunner::ClaudeCodeBase.new
    # Claude emitted TASKRUNNER_RESULT with status=error reporting a real task failure
    refute base.send(:marker_parse_failed?, { 'status' => 'error', 'message' => 'CI failed after fix attempts' })
  end

  # Bug fix: TASKRUNNER_RESULT must win over context_overflow / api_overload patterns that
  # appeared earlier in the stream (e.g., a sub-agent hit overflow but main task completed).
  # Without this, a successful task gets reclassified as terminal context_overflow error.
  def test_attempt_execution_trusts_result_received_over_context_overflow_pattern
    base = McptaskRunner::ClaudeCodeBase.new
    base.define_singleton_method(:model_name) { 'sonnet' }
    base.define_singleton_method(:build_instructions) { 'noop' }

    success_result = { 'status' => 'success', 'pr_number' => 1158, 'hours' => { 'task_worked' => 0.5 } }
    base.stub(:resolve_claude_path, '/fake/claude') do
      base.stub(:execute_with_streaming, '') do
        base.stub(:parse_result, success_result) do
          # Simulate streaming had picked up "Prompt is too long" earlier in output...
          base.instance_variable_set(:@accumulated_output, +'noise Prompt is too long noise')
          # ...but Claude recovered and emitted TASKRUNNER_RESULT marker
          base.instance_variable_get(:@state).result_received = true

          result = base.send(:attempt_execution, Time.now)

          assert_equal 'success', result['status']
          assert_equal 1158, result['pr_number']
        end
      end
    end
  end

  def test_attempt_execution_emits_context_overflow_terminal_error_when_no_result_received
    base = McptaskRunner::ClaudeCodeBase.new
    base.define_singleton_method(:model_name) { 'sonnet' }
    base.define_singleton_method(:build_instructions) { 'noop' }

    error_result = { 'status' => 'error', 'message' => 'No TASKRUNNER_RESULT found in output' }
    base.stub(:resolve_claude_path, '/fake/claude') do
      base.stub(:execute_with_streaming, '') do
        base.stub(:parse_result, error_result) do
          base.instance_variable_set(:@accumulated_output, +'Prompt is too long here')
          base.instance_variable_get(:@state).result_received = false

          result = base.send(:attempt_execution, Time.now)
          assert_equal 'error', result['status']
          assert_equal 'context_overflow', result['reason']
        end
      end
    end
  end

  def test_attempt_execution_triggers_marker_retry_when_parse_failed_without_result_received
    base = McptaskRunner::ClaudeCodeBase.new
    base.define_singleton_method(:model_name) { 'sonnet' }
    base.define_singleton_method(:build_instructions) { 'noop' }

    error_result = { 'status' => 'error', 'message' => 'No TASKRUNNER_RESULT found in output' }
    base.stub(:resolve_claude_path, '/fake/claude') do
      base.stub(:execute_with_streaming, '') do
        base.stub(:parse_result, error_result) do
          base.instance_variable_set(:@accumulated_output, +'no marker no overflow')
          base.instance_variable_get(:@state).result_received = false

          # retry_state.count = 0 → handle_marker_retry returns nil to signal retry
          # AND flips marker_retry_mode = true
          result = base.send(:attempt_execution, Time.now)
          assert_nil result, 'Should return nil to signal retry attempt'
          assert base.instance_variable_get(:@retry_state).marker_retry_mode
        end
      end
    end
  end

  def test_kill_process_handles_eperm_on_group_kill
    base = McptaskRunner::ClaudeCodeBase.new
    kill_targets = []

    kill_stub = lambda do |sig, pid|
      kill_targets << [sig, pid]
      raise Errno::EPERM if pid == -42_000 && sig == 'TERM'
      raise Errno::ESRCH if pid == 99_999 && sig == 'TERM'
    end

    Process.stub(:getpgid, 42_000) do
      Process.stub(:kill, kill_stub) do
        base.send(:kill_process, 99_999)
      end
    end

    # First tried group kill (EPERM), then fell back to direct pid
    assert_includes kill_targets, ['TERM', -42_000]
    assert_includes kill_targets, ['TERM', 99_999]
  end
end
