require 'test_helper'
require_relative '../../lib/wv_runner/services/output_formatter'

class OutputFormatterTest < Minitest::Test
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
end
