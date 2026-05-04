# frozen_string_literal: true

require 'test_helper'

class WorkLoopUrgentBugSwitchTest < Minitest::Test
  def loop_with_git(branch:, checkout_success: true, checkout_output: '')
    McptaskRunner::WorkLoop.new.tap do |instance|
      instance.define_singleton_method(:current_git_branch) { branch }
      instance.define_singleton_method(:checkout_main_branch) { [checkout_success, checkout_output] }
    end
  end

  def test_switches_to_main_when_urgent_bug_pending_on_feature_branch
    checkout_invoked = false
    loop_instance = McptaskRunner::WorkLoop.new
    loop_instance.define_singleton_method(:current_git_branch) { 'feature/9508-foo' }
    loop_instance.define_singleton_method(:checkout_main_branch) { checkout_invoked = true; [true, ''] }

    result = { 'status' => 'urgent_bug_pending', 'bug_task_id' => 9999 }
    loop_instance.send(:switch_to_main_if_urgent_bug, result)

    assert checkout_invoked
    assert_equal 'urgent_bug_pending', result['status']
  end

  def test_marks_dirty_branch_when_checkout_fails
    loop_instance = loop_with_git(branch: 'feature/9508-foo', checkout_success: false, checkout_output: 'error: local changes')

    result = { 'status' => 'urgent_bug_pending', 'bug_task_id' => 9999 }
    loop_instance.send(:switch_to_main_if_urgent_bug, result)

    assert_equal 'urgent_bug_pending_dirty_branch', result['status']
    assert_equal 'feature/9508-foo', result['dirty_branch']
  end

  def test_no_op_when_already_on_main
    checkout_invoked = false
    loop_instance = McptaskRunner::WorkLoop.new
    loop_instance.define_singleton_method(:current_git_branch) { 'main' }
    loop_instance.define_singleton_method(:checkout_main_branch) { checkout_invoked = true; [true, ''] }

    result = { 'status' => 'urgent_bug_pending', 'bug_task_id' => 9999 }
    loop_instance.send(:switch_to_main_if_urgent_bug, result)

    refute checkout_invoked
    assert_equal 'urgent_bug_pending', result['status']
  end

  def test_no_op_when_already_on_master
    checkout_invoked = false
    loop_instance = McptaskRunner::WorkLoop.new
    loop_instance.define_singleton_method(:current_git_branch) { 'master' }
    loop_instance.define_singleton_method(:checkout_main_branch) { checkout_invoked = true; [true, ''] }

    result = { 'status' => 'urgent_bug_pending' }
    loop_instance.send(:switch_to_main_if_urgent_bug, result)

    refute checkout_invoked
  end

  def test_no_op_for_non_urgent_bug_status
    branch_invoked = false
    loop_instance = McptaskRunner::WorkLoop.new
    loop_instance.define_singleton_method(:current_git_branch) { branch_invoked = true; 'feature/x' }
    loop_instance.define_singleton_method(:checkout_main_branch) { [true, ''] }

    result = { 'status' => 'success' }
    loop_instance.send(:switch_to_main_if_urgent_bug, result)

    refute branch_invoked, 'should short-circuit before checking branch'
  end

  def test_no_op_for_non_hash_result
    loop_instance = McptaskRunner::WorkLoop.new
    assert_nil loop_instance.send(:switch_to_main_if_urgent_bug, nil)
  end
end
