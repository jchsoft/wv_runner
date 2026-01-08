require 'test_helper'
require_relative '../../lib/wv_runner/services/output_formatter'

class OutputFormatterTest < Minitest::Test
  def setup
    # Reset verbose mode and ascii mode before each test
    WvRunner::OutputFormatter.verbose_mode = false
    WvRunner::OutputFormatter.ascii_mode = false # Force emoji mode for backwards compatibility
  end

  def teardown
    WvRunner::OutputFormatter.ascii_mode = nil # Reset to auto-detect
  end

  def test_format_line_adds_blank_line_before_output
    line = 'some output'
    result = WvRunner::OutputFormatter.format_line(line)
    assert_match /\n\[Claude\] some output/, result
  end

  def test_format_line_with_simple_json
    json_line = '{"status": "success", "value": 42}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # Result should have blank line and be pretty printed
    assert_match /\n\[Claude\] /, result
    assert_includes result, '"status":'
    assert_includes result, '"success"'
  end

  def test_format_line_with_nested_json
    json_line = '{"task": {"id": 123, "name": "Test"}, "status": "ok"}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    assert_match /\n\[Claude\] /, result
    assert_includes result, '"task":'
    assert_includes result, '"id":'
  end

  def test_format_line_processes_escaped_newlines
    line = 'Line 1\\nLine 2\\nLine 3'
    result = WvRunner::OutputFormatter.format_line(line)
    assert_includes result, "\n"
    assert_match /Line 1\nLine 2\nLine 3/, result
  end

  def test_format_line_with_escaped_json
    json_line = '{\"status\": \"success\"}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    assert_match /\n\[Claude\] /, result
  end

  def test_format_line_with_plain_text_containing_escaped_newlines
    line = 'Error occurred\\nDetails: something failed\\nPlease retry'
    result = WvRunner::OutputFormatter.format_line(line)
    # Should convert \n to actual newlines
    assert_includes result, "\n"
  end

  def test_format_line_with_invalid_json_falls_back_to_newline_processing
    line = '{invalid json content}'
    result = WvRunner::OutputFormatter.format_line(line)
    # Should still add [Claude] prefix even if not valid JSON
    assert_match /\n\[Claude\]/, result
  end

  def test_strips_system_reminder_from_non_json_output
    line = 'Some text<system-reminder>Internal note</system-reminder>More text'
    result = WvRunner::OutputFormatter.format_line(line)
    assert_includes result, "Some text"
    assert_includes result, "More text"
    refute_includes result, "system-reminder"
    refute_includes result, "Internal note"
  end

  # Verbose mode tests (original behavior)
  def test_verbose_mode_outputs_full_json
    WvRunner::OutputFormatter.verbose_mode = true
    json_line = '{"type": "assistant", "message": {"content": [{"type": "text", "text": "Hello"}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # In verbose mode, should output full pretty-printed JSON
    assert_includes result, '"type":'
    assert_includes result, '"message":'
    assert_includes result, '"content":'
  end

  def test_verbose_mode_strips_system_reminders
    WvRunner::OutputFormatter.verbose_mode = true
    json_line = '{"type": "assistant", "message": {"content": [{"type": "text", "text": "Before<system-reminder>Secret stuff</system-reminder>After"}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # Should strip system-reminder even in verbose mode
    assert_includes result, "Before"
    assert_includes result, "After"
    refute_includes result, "system-reminder"
    refute_includes result, "Secret stuff"
  end

  # Normal mode tests (filtered output)
  def test_normal_mode_extracts_text_content
    WvRunner::OutputFormatter.verbose_mode = false
    json_line = '{"type": "assistant", "message": {"content": [{"type": "text", "text": "Hello World"}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # In normal mode, should extract and format just the text
    assert_includes result, "Hello World"
    # Should not include full JSON structure
    refute_includes result, '"message":'
  end

  def test_normal_mode_with_tool_use
    WvRunner::OutputFormatter.verbose_mode = false
    json_line = '{"type": "assistant", "message": {"content": [{"type": "tool_use", "id": "tool_123", "name": "ReadFile", "input": {"path": "/tmp/file.txt"}}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # Should extract tool use information
    assert_includes result, "Tool: ReadFile"
    assert_includes result, "ID: tool_123"
    assert_includes result, "path"
  end

  def test_normal_mode_with_tool_result
    WvRunner::OutputFormatter.verbose_mode = false
    json_line = '{"type": "assistant", "message": {"content": [{"type": "tool_result", "content": "File contents here", "is_error": false}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # Should extract tool result
    assert_includes result, "Tool Result"
    assert_includes result, "OK"
    assert_includes result, "File contents here"
  end

  def test_normal_mode_with_tool_result_error
    WvRunner::OutputFormatter.verbose_mode = false
    json_line = '{"type": "assistant", "message": {"content": [{"type": "tool_result", "content": "File not found", "is_error": true}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # Should mark as ERROR
    assert_includes result, "ERROR"
    assert_includes result, "File not found"
  end

  def test_normal_mode_with_multiple_content_items
    WvRunner::OutputFormatter.verbose_mode = false
    json_line = '{"type": "assistant", "message": {"content": [{"type": "text", "text": "First"}, {"type": "text", "text": "Second"}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # Should include both text items
    assert_includes result, "First"
    assert_includes result, "Second"
  end

  def test_normal_mode_without_message_content
    WvRunner::OutputFormatter.verbose_mode = false
    json_line = '{"type": "system", "data": "some data"}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # Should fall back to verbose output when no message.content
    assert_includes result, '"type":'
  end

  def test_strips_system_reminder_tags
    WvRunner::OutputFormatter.verbose_mode = false
    json_line = '{"type": "assistant", "message": {"content": [{"type": "text", "text": "Hello<system-reminder>Internal note</system-reminder>World"}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # Should remove system-reminder tags
    assert_includes result, "Hello"
    assert_includes result, "World"
    refute_includes result, "system-reminder"
    refute_includes result, "Internal note"
  end

  def test_strips_multiline_system_reminder_tags
    WvRunner::OutputFormatter.verbose_mode = false
    # Use \\n for escaped newlines as they come from JSON stream
    text_with_reminder = 'Before\\n<system-reminder>\\nMultiple\\nlines\\n</system-reminder>\\nAfter'
    json_line = '{"type": "assistant", "message": {"content": [{"type": "text", "text": "' + text_with_reminder + '"}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    assert_includes result, "Before"
    assert_includes result, "After"
    refute_includes result, "Multiple"
    refute_includes result, "lines"
  end

  def test_verbose_mode_flag
    assert_equal false, WvRunner::OutputFormatter.verbose_mode
    WvRunner::OutputFormatter.verbose_mode = true
    assert_equal true, WvRunner::OutputFormatter.verbose_mode
  end

  def test_normal_mode_with_todo_write_formats_with_emoji
    WvRunner::OutputFormatter.verbose_mode = false
    json_line = '{"type": "assistant", "message": {"content": [{"type": "tool_use", "id": "tool_456", "name": "TodoWrite", "input": {"todos": [{"content": "First task", "status": "completed", "activeForm": "Doing first"}, {"content": "Second task", "status": "in_progress", "activeForm": "Doing second"}, {"content": "Third task", "status": "pending", "activeForm": "Doing third"}]}}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # Should format with emoji instead of JSON
    assert_includes result, "Tool: TodoWrite"
    assert_includes result, "✅ First task"
    assert_includes result, "🔄 Second task"
    assert_includes result, "⏳ Third task"
    # Should NOT include JSON structure
    refute_includes result, '"todos"'
    refute_includes result, '"activeForm"'
  end

  def test_format_todo_write_input_maps_statuses_to_emoji
    todos = [
      { 'content' => 'Done task', 'status' => 'completed' },
      { 'content' => 'Working task', 'status' => 'in_progress' },
      { 'content' => 'Waiting task', 'status' => 'pending' },
      { 'content' => 'Unknown status', 'status' => 'unknown' }
    ]
    result = WvRunner::OutputFormatter.format_todo_write_input(todos)
    assert_includes result, "✅ Done task"
    assert_includes result, "🔄 Working task"
    assert_includes result, "⏳ Waiting task"
    assert_includes result, "⏳ Unknown status" # fallback to pending emoji
  end

  def test_strips_system_reminder_from_tool_result_content
    WvRunner::OutputFormatter.verbose_mode = false
    reminder_content = "File contents here<system-reminder>\nWhenever you read a file...\n</system-reminder>\nMore content"
    json_line = '{"type": "assistant", "message": {"content": [{"type": "tool_result", "content": "' + reminder_content.gsub("\n", "\\n") + '", "is_error": false}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # Should include actual content
    assert_includes result, "File contents here"
    assert_includes result, "More content"
    # Should NOT include system-reminder content
    refute_includes result, "system-reminder"
    refute_includes result, "Whenever you read a file"
  end

  def test_normal_mode_with_thinking_content
    WvRunner::OutputFormatter.verbose_mode = false
    json_line = '{"type": "assistant", "message": {"content": [{"type": "thinking", "thinking": "Now let me update the third failing test:", "signature": "EtEBCkYICxgCKkBrkSKI..."}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # Should format thinking with icon and quoted text
    assert_includes result, "thinking:"
    assert_includes result, "💭"
    assert_includes result, '"Now let me update the third failing test:"'
    # Should NOT include signature or raw JSON structure
    refute_includes result, "signature"
    refute_includes result, "EtEBCkYICxgCKkBrkSKI"
  end

  def test_format_thinking_content_formats_with_icon
    item = { 'type' => 'thinking', 'thinking' => 'Let me analyze this problem', 'signature' => 'abc123' }
    result = WvRunner::OutputFormatter.format_thinking_content(item)
    assert_equal 'thinking: 💭 "Let me analyze this problem"', result
  end

  def test_normal_mode_with_mixed_content_including_thinking
    WvRunner::OutputFormatter.verbose_mode = false
    json_line = '{"type": "assistant", "message": {"content": [{"type": "thinking", "thinking": "Planning my approach"}, {"type": "text", "text": "Here is the solution"}]}}'
    result = WvRunner::OutputFormatter.format_line(json_line)
    # Should include both thinking and text
    assert_includes result, '💭 "Planning my approach"'
    assert_includes result, "Here is the solution"
  end

  # BMP fallback mode tests for terminals without emoji support
  def test_ascii_mode_todo_write_uses_bmp_icons
    WvRunner::OutputFormatter.ascii_mode = true
    todos = [
      { 'content' => 'Done task', 'status' => 'completed' },
      { 'content' => 'Working task', 'status' => 'in_progress' },
      { 'content' => 'Waiting task', 'status' => 'pending' }
    ]
    result = WvRunner::OutputFormatter.format_todo_write_input(todos)
    assert_includes result, "✔ Done task"
    assert_includes result, "▶ Working task"
    assert_includes result, "○ Waiting task"
    refute_includes result, "✅"
    refute_includes result, "🔄"
    refute_includes result, "⏳"
  end

  def test_ascii_mode_thinking_uses_bmp_icon
    WvRunner::OutputFormatter.ascii_mode = true
    item = { 'type' => 'thinking', 'thinking' => 'Analyzing the problem' }
    result = WvRunner::OutputFormatter.format_thinking_content(item)
    assert_equal 'thinking: … "Analyzing the problem"', result
    refute_includes result, "💭"
  end

  def test_icon_method_returns_emoji_when_not_ascii_mode
    WvRunner::OutputFormatter.ascii_mode = false
    assert_equal '✅', WvRunner::OutputFormatter.icon(:completed)
    assert_equal '🔄', WvRunner::OutputFormatter.icon(:in_progress)
    assert_equal '⏳', WvRunner::OutputFormatter.icon(:pending)
    assert_equal '💭', WvRunner::OutputFormatter.icon(:thinking)
  end

  def test_icon_method_returns_bmp_when_ascii_mode
    WvRunner::OutputFormatter.ascii_mode = true
    assert_equal '✔', WvRunner::OutputFormatter.icon(:completed)
    assert_equal '▶', WvRunner::OutputFormatter.icon(:in_progress)
    assert_equal '○', WvRunner::OutputFormatter.icon(:pending)
    assert_equal '…', WvRunner::OutputFormatter.icon(:thinking)
  end

  def test_icon_returns_empty_string_for_unknown_icon
    assert_equal '', WvRunner::OutputFormatter.icon(:unknown_icon)
  end

  def test_use_ascii_respects_explicit_ascii_mode_true
    WvRunner::OutputFormatter.ascii_mode = true
    assert WvRunner::OutputFormatter.use_ascii?
  end

  def test_use_ascii_respects_explicit_ascii_mode_false
    WvRunner::OutputFormatter.ascii_mode = false
    refute WvRunner::OutputFormatter.use_ascii?
  end
end
