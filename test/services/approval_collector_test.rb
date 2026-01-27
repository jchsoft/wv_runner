# frozen_string_literal: true

require_relative '../test_helper'

class ApprovalCollectorTest < Minitest::Test
  def setup
    WvRunner::ApprovalCollector.clear
  end

  def teardown
    WvRunner::ApprovalCollector.clear
  end

  def test_add_stores_command
    WvRunner::ApprovalCollector.add('bin/ci')
    assert_equal ['bin/ci'], WvRunner::ApprovalCollector.commands
  end

  def test_add_ignores_nil
    WvRunner::ApprovalCollector.add(nil)
    assert_empty WvRunner::ApprovalCollector.commands
  end

  def test_add_ignores_empty_string
    WvRunner::ApprovalCollector.add('')
    WvRunner::ApprovalCollector.add('   ')
    assert_empty WvRunner::ApprovalCollector.commands
  end

  def test_add_avoids_duplicates
    WvRunner::ApprovalCollector.add('bin/ci')
    WvRunner::ApprovalCollector.add('bin/ci')
    WvRunner::ApprovalCollector.add('bin/ci')
    assert_equal ['bin/ci'], WvRunner::ApprovalCollector.commands
  end

  def test_clear_removes_all_commands
    WvRunner::ApprovalCollector.add('bin/ci')
    WvRunner::ApprovalCollector.add('bin/test')
    WvRunner::ApprovalCollector.clear
    assert_empty WvRunner::ApprovalCollector.commands
  end

  def test_any_returns_false_when_empty
    refute WvRunner::ApprovalCollector.any?
  end

  def test_any_returns_true_when_has_commands
    WvRunner::ApprovalCollector.add('bin/ci')
    assert WvRunner::ApprovalCollector.any?
  end

  def test_commands_returns_copy
    WvRunner::ApprovalCollector.add('bin/ci')
    commands = WvRunner::ApprovalCollector.commands
    commands << 'bin/test'
    # Original should not be modified
    assert_equal ['bin/ci'], WvRunner::ApprovalCollector.commands
  end

  def test_extract_from_error_with_following_parts_pattern
    error = 'This Bash command contains multiple operations. The following parts require approval: if [ -f "bin/ci" ], then bin/ci, else echo "skipping", fi'
    WvRunner::ApprovalCollector.extract_from_error(error)
    assert_equal ['if [ -f "bin/ci" ], then bin/ci, else echo "skipping", fi'], WvRunner::ApprovalCollector.commands
  end

  def test_extract_from_error_with_requires_approval_pattern
    error = 'This command requires approval: rm -rf /tmp/test'
    WvRunner::ApprovalCollector.extract_from_error(error)
    assert_equal ['rm -rf /tmp/test'], WvRunner::ApprovalCollector.commands
  end

  def test_extract_from_error_ignores_unrelated_messages
    error = 'Some other error without approval text'
    WvRunner::ApprovalCollector.extract_from_error(error)
    assert_empty WvRunner::ApprovalCollector.commands
  end

  def test_extract_from_error_handles_nil
    WvRunner::ApprovalCollector.extract_from_error(nil)
    assert_empty WvRunner::ApprovalCollector.commands
  end

  def test_print_summary_outputs_nothing_when_empty
    output = capture_io { WvRunner::ApprovalCollector.print_summary }
    assert_empty output[0]
  end

  def test_print_summary_outputs_commands_when_present
    WvRunner::ApprovalCollector.add('bin/ci')
    WvRunner::ApprovalCollector.add('bin/test')

    output = capture_io { WvRunner::ApprovalCollector.print_summary }
    assert_includes output[0], 'COMMANDS THAT REQUIRED APPROVAL'
    assert_includes output[0], 'bin/ci'
    assert_includes output[0], 'bin/test'
    assert_includes output[0], 'settings.json'
  end
end
