# frozen_string_literal: true

require_relative '../test_helper'

class ApprovalCollectorTest < Minitest::Test
  def setup
    McptaskRunner::ApprovalCollector.clear
  end

  def teardown
    McptaskRunner::ApprovalCollector.clear
  end

  def test_add_stores_command
    McptaskRunner::ApprovalCollector.add('bin/ci')
    assert_equal ['bin/ci'], McptaskRunner::ApprovalCollector.commands
  end

  def test_add_ignores_nil
    McptaskRunner::ApprovalCollector.add(nil)
    assert_empty McptaskRunner::ApprovalCollector.commands
  end

  def test_add_ignores_empty_string
    McptaskRunner::ApprovalCollector.add('')
    McptaskRunner::ApprovalCollector.add('   ')
    assert_empty McptaskRunner::ApprovalCollector.commands
  end

  def test_add_avoids_duplicates
    McptaskRunner::ApprovalCollector.add('bin/ci')
    McptaskRunner::ApprovalCollector.add('bin/ci')
    McptaskRunner::ApprovalCollector.add('bin/ci')
    assert_equal ['bin/ci'], McptaskRunner::ApprovalCollector.commands
  end

  def test_clear_removes_all_commands
    McptaskRunner::ApprovalCollector.add('bin/ci')
    McptaskRunner::ApprovalCollector.add('bin/test')
    McptaskRunner::ApprovalCollector.clear
    assert_empty McptaskRunner::ApprovalCollector.commands
  end

  def test_any_returns_false_when_empty
    refute McptaskRunner::ApprovalCollector.any?
  end

  def test_any_returns_true_when_has_commands
    McptaskRunner::ApprovalCollector.add('bin/ci')
    assert McptaskRunner::ApprovalCollector.any?
  end

  def test_commands_returns_copy
    McptaskRunner::ApprovalCollector.add('bin/ci')
    commands = McptaskRunner::ApprovalCollector.commands
    commands << 'bin/test'
    # Original should not be modified
    assert_equal ['bin/ci'], McptaskRunner::ApprovalCollector.commands
  end

  def test_extract_from_error_with_following_parts_pattern
    error = 'This Bash command contains multiple operations. The following parts require approval: if [ -f "bin/ci" ], then bin/ci, else echo "skipping", fi'
    McptaskRunner::ApprovalCollector.extract_from_error(error)
    assert_equal ['if [ -f "bin/ci" ], then bin/ci, else echo "skipping", fi'], McptaskRunner::ApprovalCollector.commands
  end

  def test_extract_from_error_with_requires_approval_pattern
    error = 'This command requires approval: rm -rf /tmp/test'
    McptaskRunner::ApprovalCollector.extract_from_error(error)
    assert_equal ['rm -rf /tmp/test'], McptaskRunner::ApprovalCollector.commands
  end

  def test_extract_from_error_ignores_unrelated_messages
    error = 'Some other error without approval text'
    McptaskRunner::ApprovalCollector.extract_from_error(error)
    assert_empty McptaskRunner::ApprovalCollector.commands
  end

  def test_extract_from_error_handles_nil
    McptaskRunner::ApprovalCollector.extract_from_error(nil)
    assert_empty McptaskRunner::ApprovalCollector.commands
  end

  def test_print_summary_outputs_nothing_when_empty
    output = capture_io { McptaskRunner::ApprovalCollector.print_summary }
    assert_empty output[0]
  end

  def test_print_summary_outputs_commands_when_present
    McptaskRunner::ApprovalCollector.add('bin/ci')
    McptaskRunner::ApprovalCollector.add('bin/test')

    output = capture_io { McptaskRunner::ApprovalCollector.print_summary }
    assert_includes output[0], 'COMMANDS THAT REQUIRED APPROVAL'
    assert_includes output[0], 'bin/ci'
    assert_includes output[0], 'bin/test'
    assert_includes output[0], 'settings.json'
  end
end
