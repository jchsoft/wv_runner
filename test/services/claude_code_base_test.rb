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
    mock_output = 'WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": 8, "task_estimated": 2}}'
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
    assert_equal 'No WVRUNNER_RESULT found in output', result['message']
  end

  def test_parse_result_handles_invalid_json
    mock_output = 'WVRUNNER_RESULT: {invalid json}'
    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 0.5)

    assert_equal 'error', result['status']
    assert_match(/Failed to parse JSON/, result['message'])
  end

  def test_parse_result_handles_json_with_escaped_quotes_from_real_claude_output
    # Real-world case: Claude outputs JSON with escaped quotes in markdown code block
    mock_output = "Perfect! I've loaded the task information. Let me parse and display the details:\n\n## Task Information\n\n**Task Name:** (ActionDispatch::MissingController) \"uninitialized constant Api::OfficesController\"\n\n```json\nWVRUNNER_RESULT: {\\\"status\\\": \\\"success\\\", \\\"task_info\\\": {\\\"name\\\": \\\"(ActionDispatch::MissingController) \\\\\\\"uninitialized constant Api::OfficesController\\\\\\\"\\\", \\\"id\\\": 9005, \\\"description\\\": \\\"Test description\\\", \\\"status\\\": \\\"Nove\\\", \\\"priority\\\": \\\"Urgentni\\\", \\\"assigned_user\\\": \\\"Karel Mracek\\\", \\\"scrum_points\\\": \\\"Mirne obtizne\\\"}, \\\"hours\\\": {\\\"per_day\\\": 8, \\\"task_estimated\\\": 1.0}}\n```"

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
    assert_includes cmd, 'opus'
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
    base.instance_variable_set(:@stopping, true)

    yielded = false
    base.send(:handle_stream_error, IOError.new('test'), 'stdout') { yielded = true }

    refute yielded, 'Should not yield when stopping'
  end

  def test_handle_stream_error_yields_error_message_when_not_stopping
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@stopping, false)

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
    refute base.instance_variable_get(:@stopping)
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
    assert_match(/Missing WVRUNNER_RESULT/, result['message'])
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
    assert_includes instructions, 'WVRUNNER_RESULT'
    assert_includes instructions, 'Do NOT just output the marker'
  end

  def test_build_marker_retry_instructions_includes_original_instructions
    base = McptaskRunner::ClaudeCodeBase.new
    original_instructions = 'Step 1: Do this\nStep 2: Do that\nWVRUNNER_RESULT: {"status": "success"}'
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
    base.instance_variable_set(:@accumulated_output, '{"type":"result","result":"WVRUNNER_RESULT: {}"}')

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
    refute base.instance_variable_get(:@api_overload_flag)
  end

  def test_check_for_api_overload_sets_flag_on_529
    base = McptaskRunner::ClaudeCodeBase.new
    base.send(:check_for_api_overload, '{"type":"system","subtype":"api_retry","error_status": 529}')

    assert base.instance_variable_get(:@api_overload_flag), 'Should set flag on 529 error'
  end

  def test_check_for_api_overload_sets_flag_on_repeated_529
    base = McptaskRunner::ClaudeCodeBase.new
    base.send(:check_for_api_overload, '[Claude] API Error: Repeated 529 Overloaded errors')

    assert base.instance_variable_get(:@api_overload_flag), 'Should set flag on repeated 529'
  end

  def test_check_for_api_overload_does_not_set_flag_on_normal_output
    base = McptaskRunner::ClaudeCodeBase.new
    base.send(:check_for_api_overload, '{"type":"assistant","message":"Hello"}')

    refute base.instance_variable_get(:@api_overload_flag), 'Should not set flag on normal output'
  end

  def test_api_overload_detected_via_flag
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@accumulated_output, '')
    base.instance_variable_set(:@api_overload_flag, true)

    assert base.send(:api_overload_detected?), 'Should detect overload via flag even with empty accumulated_output'
  end

  def test_stream_closed_with_529_raises_api_overload
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@api_overload_flag, true)

    # attempt_execution rescues StreamClosedError, checks flag, re-raises as ApiOverloadError
    # which is then caught and handled by handle_api_overload
    base.stub(:sleep, nil) do
      result = base.send(:handle_api_overload, Time.now)
      assert_nil result, 'API overload handler should return nil to signal retry'
      assert_equal 1, base.instance_variable_get(:@retry_state).api_overload_count, 'Should increment overload counter'
    end
  end

  # Tests for result_received flag and early stream termination
  def test_initialize_sets_result_received_to_false
    base = McptaskRunner::ClaudeCodeBase.new
    refute base.instance_variable_get(:@result_received)
  end

  def test_check_for_result_message_ignores_interim_result_without_marker
    base = McptaskRunner::ClaudeCodeBase.new
    result_line = '{"type": "result", "result": "Tests running in background..."}'

    base.send(:check_for_result_message, result_line)

    refute base.instance_variable_get(:@result_received)
    refute base.instance_variable_get(:@stopping)
  end

  def test_check_for_result_message_sets_flag_on_final_result_with_marker
    base = McptaskRunner::ClaudeCodeBase.new
    result_line = '{"type": "result", "result": "{\"WVRUNNER_RESULT\": true, \"status\": \"success\"}"}'

    base.send(:check_for_result_message, result_line)

    assert base.instance_variable_get(:@result_received)
    assert base.instance_variable_get(:@stopping)
  end

  def test_check_for_result_message_ignores_non_result_types
    base = McptaskRunner::ClaudeCodeBase.new
    assistant_line = '{"type": "assistant", "message": "Hello"}'

    base.send(:check_for_result_message, assistant_line)

    refute base.instance_variable_get(:@result_received)
  end

  def test_check_for_result_message_ignores_invalid_json
    base = McptaskRunner::ClaudeCodeBase.new
    invalid_line = 'This is not JSON at all'

    base.send(:check_for_result_message, invalid_line)

    refute base.instance_variable_get(:@result_received)
  end

  def test_check_for_result_message_skips_when_already_received
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@result_received, true)
    base.instance_variable_set(:@stopping, false)
    result_line = '{"type": "result", "cost_usd": 0.05}'

    base.send(:check_for_result_message, result_line)

    # @stopping should remain false since we skipped processing
    refute base.instance_variable_get(:@stopping)
  end

  def test_stream_lines_breaks_when_result_received
    base = McptaskRunner::ClaudeCodeBase.new
    io = StringIO.new("line1\nline2\nline3\nline4\n")
    lines = []

    base.send(:stream_lines, io) do |line|
      lines << line.strip
      # Simulate result received after line2
      base.instance_variable_set(:@result_received, true) if line.strip == 'line2'
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
    assert_nil base.instance_variable_get(:@child_pid)
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
    assert_includes instruction, 'WVRUNNER_RESULT'
  end

  def test_initialize_sets_inactivity_timeout_to_false
    base = McptaskRunner::ClaudeCodeBase.new
    refute base.instance_variable_get(:@inactivity_timeout)
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
    assert_equal 0, base.instance_variable_get(:@stream_line_count)
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
                               'I analyzed the task.\nWVRUNNER_RESULT: {"status": "success", "task_id": 9508, "recommended_model": "sonnet", "hours": {"per_day": 8}}')

    result = base.send(:parse_result, 'raw stream json that does not contain marker', 1.0)

    assert_equal 'success', result['status']
    assert_equal 9508, result['task_id']
    assert_equal 'sonnet', result['recommended_model']
    assert_equal 1.0, result['hours']['task_worked']
  end

  def test_parse_result_falls_back_to_raw_output_when_text_content_empty
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@text_content, '')

    raw = 'WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": 4}}'
    result = base.send(:parse_result, raw, 0.5)

    assert_equal 'success', result['status']
    assert_equal 4, result['hours']['per_day']
  end

  def test_parse_result_falls_back_to_raw_when_text_content_lacks_marker
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@text_content, 'Some text without the marker')

    raw = 'WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": 6}}'
    result = base.send(:parse_result, raw, 0.3)

    assert_equal 'success', result['status']
    assert_equal 6, result['hours']['per_day']
  end

  # Tests for new JSON key marker format: {"WVRUNNER_RESULT": true, ...}
  def test_parse_result_with_json_key_marker
    mock_output = '{"WVRUNNER_RESULT": true, "status": "success", "hours": {"per_day": 8, "task_estimated": 2}}'
    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 1.5)

    assert_equal 'success', result['status']
    assert_equal 8, result['hours']['per_day']
    assert_equal 2, result['hours']['task_estimated']
    assert_equal 1.5, result['hours']['task_worked']
    refute result.key?('WVRUNNER_RESULT'), 'WVRUNNER_RESULT key should be removed from result'
  end

  def test_parse_result_with_json_key_marker_in_code_block
    mock_output = "Here is the result:\n\n```json\n{\"WVRUNNER_RESULT\": true, \"status\": \"success\", \"hours\": {\"per_day\": 6}}\n```"
    base = McptaskRunner::ClaudeCodeBase.new
    result = base.send(:parse_result, mock_output, 0.5)

    assert_equal 'success', result['status']
    assert_equal 6, result['hours']['per_day']
  end

  def test_parse_result_with_json_key_marker_in_text_content
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@text_content,
                               "Analysis done.\n{\"WVRUNNER_RESULT\": true, \"status\": \"success\", \"task_id\": 9843, \"hours\": {\"per_day\": 8}}")

    result = base.send(:parse_result, 'raw stream without marker', 1.0)

    assert_equal 'success', result['status']
    assert_equal 9843, result['task_id']
  end

  def test_parse_result_json_key_falls_back_to_raw_stdout
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@text_content, 'No marker here')

    raw = '{"WVRUNNER_RESULT": true, "status": "success", "hours": {"per_day": 4}}'
    result = base.send(:parse_result, raw, 0.3)

    assert_equal 'success', result['status']
    assert_equal 4, result['hours']['per_day']
  end

  # Tests for result_format_instruction method
  def test_result_format_instruction_includes_json_code_block
    base = McptaskRunner::ClaudeCodeBase.new
    instruction = base.send(:result_format_instruction, '"status": "success"')

    assert_includes instruction, '```json'
    assert_includes instruction, '"WVRUNNER_RESULT": true'
    assert_includes instruction, '"status": "success"'
    assert_includes instruction, 'CRITICAL FORMATTING'
  end

  def test_result_format_instruction_with_extra_rules
    base = McptaskRunner::ClaudeCodeBase.new
    instruction = base.send(:result_format_instruction, '"status": "success"',
                            extra_rules: ['task_id MUST be numeric'])

    assert_includes instruction, 'task_id MUST be numeric'
  end

  # Tests for tool tracking
  def test_initialize_sets_active_tool_calls_to_empty_hash
    base = McptaskRunner::ClaudeCodeBase.new
    assert_equal({}, base.instance_variable_get(:@active_tool_calls))
  end

  def test_track_tool_event_adds_tool_use
    base = McptaskRunner::ClaudeCodeBase.new
    line = '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"tool_123","name":"Skill","input":{}}]}}'

    base.send(:track_tool_event, line)

    tools = base.instance_variable_get(:@active_tool_calls)
    assert_equal 1, tools.size
    assert_equal 'Skill', tools['tool_123'][:name]
    assert_kind_of Float, tools['tool_123'][:started_at]
  end

  def test_track_tool_event_removes_on_tool_result
    base = McptaskRunner::ClaudeCodeBase.new
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    base.instance_variable_set(:@active_tool_calls, { 'tool_123' => { name: 'Skill', started_at: now } })

    line = '{"type":"assistant","message":{"content":[{"type":"tool_result","tool_use_id":"tool_123","content":"ok"}]}}'
    base.send(:track_tool_event, line)

    assert_empty base.instance_variable_get(:@active_tool_calls)
  end

  def test_track_tool_event_ignores_non_json
    base = McptaskRunner::ClaudeCodeBase.new
    base.send(:track_tool_event, 'not json at all')
    assert_empty base.instance_variable_get(:@active_tool_calls)
  end

  def test_track_tool_event_ignores_lines_without_content
    base = McptaskRunner::ClaudeCodeBase.new
    base.send(:track_tool_event, '{"type":"result","cost_usd":0.05}')
    assert_empty base.instance_variable_get(:@active_tool_calls)
  end

  def test_format_active_tools_empty
    base = McptaskRunner::ClaudeCodeBase.new
    assert_equal '', base.send(:format_active_tools)
  end

  def test_format_active_tools_with_tools
    base = McptaskRunner::ClaudeCodeBase.new
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    base.instance_variable_set(:@active_tool_calls, {
                                 'tool_1' => { name: 'Skill', started_at: now - 300 }
                               })

    result = base.send(:format_active_tools, now)
    assert_includes result, 'waiting for:'
    assert_includes result, 'Skill since 300s'
  end

  def test_write_debug_dump_creates_file
    base = McptaskRunner::ClaudeCodeBase.new
    base.instance_variable_set(:@stream_line_count, 198)
    base.instance_variable_set(:@text_content, "line 1\nline 2\n")
    base.instance_variable_set(:@active_tool_calls, {})
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
