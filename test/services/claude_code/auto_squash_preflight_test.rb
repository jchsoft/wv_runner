# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'json'
require 'mcptask_runner/services/claude_code/auto_squash_base'

class AutoSquashPreflightTest < Minitest::Test
  # Concrete subclass used to instantiate AutoSquashBase in tests.
  class FakeAutoSquash < McptaskRunner::ClaudeCode::AutoSquashBase
    def initialize(task_id:, verbose: false)
      super(verbose: verbose)
      @task_id = task_id
    end

    def model_name = 'sonnet'
    def build_instructions = '[FAKE] real path was taken'
  end

  def setup
    @executor = FakeAutoSquash.new(task_id: 10358)
  end

  def test_pr_matches_task_word_boundary
    assert_match_pr({ 'title' => 'Fix bug 10358', 'body' => '', 'headRefName' => 'main' }, 10358)
    refute_match_pr({ 'title' => 'Fix bug 103589', 'body' => '', 'headRefName' => 'main' }, 10358)
    refute_match_pr({ 'title' => 'Fix bug 110358', 'body' => '', 'headRefName' => 'main' }, 10358)
  end

  def test_pr_matches_task_body_uri
    pr = { 'title' => 'random', 'body' => "Closes mcptask://pieces/jchsoft/10358 here", 'headRefName' => 'feature/x' }
    assert_match_pr(pr, 10358)
  end

  def test_pr_matches_task_branch_name
    assert_match_pr({ 'title' => '', 'body' => '', 'headRefName' => 'feature/10358-add-thing' }, 10358)
    assert_match_pr({ 'title' => '', 'body' => '', 'headRefName' => 'fix/10358' }, 10358)
    refute_match_pr({ 'title' => '', 'body' => '', 'headRefName' => 'feature/110358-other' }, 10358)
  end

  def test_preflight_returns_nil_when_gh_fails
    stub_gh_pr_list(stdout: '', success: false) do
      assert_nil @executor.send(:preflight_merged_pr_match)
    end
  end

  def test_preflight_returns_nil_when_no_match
    payload = [{ 'number' => 99, 'title' => 'Unrelated', 'body' => '', 'headRefName' => 'main', 'mergeCommit' => { 'oid' => 'abc1234' } }]
    stub_gh_pr_list(stdout: JSON.dump(payload), success: true) do
      assert_nil @executor.send(:preflight_merged_pr_match)
    end
  end

  def test_preflight_returns_hash_when_pr_matches
    payload = [{
      'number' => 42,
      'title' => 'fix: bump runner 10358',
      'body' => '',
      'headRefName' => 'fix/10358-x',
      'mergeCommit' => { 'oid' => 'deadbeefcafef00d' }
    }]
    stub_gh_pr_list(stdout: JSON.dump(payload), success: true) do
      result = @executor.send(:preflight_merged_pr_match)
      assert_equal({ pr_number: 42, merge_commit: 'deadbeefcafef00d' }, result)
    end
  end

  def test_preflight_nil_when_no_task_id
    executor = FakeAutoSquash.new(task_id: nil)
    assert_nil executor.send(:preflight_merged_pr_match)
  end

  def test_fast_track_instructions_include_task_and_pr
    instructions = @executor.send(:fast_track_already_done_instructions,
                                  pr_number: 42, merge_commit: 'deadbeefcafef00d')
    assert_includes instructions, '#42'
    assert_includes instructions, '10358'
    assert_includes instructions, 'TASKRUNNER_RESULT'
    assert_includes instructions, '"status":"already_done"'
    assert_includes instructions, 'deadbee'
  end

  def test_run_calls_fast_track_when_preflight_matches
    payload = [{ 'number' => 42, 'title' => '10358', 'body' => '', 'headRefName' => 'main', 'mergeCommit' => { 'oid' => 'deadbeefcafef00d' } }]
    called = []
    @executor.define_singleton_method(:run_fast_track_already_done) { |p| called << p; { 'status' => 'already_done' } }
    @executor.define_singleton_method(:run_with_retry) { |_| flunk('full execution path should not run when preflight matches') }

    stub_gh_pr_list(stdout: JSON.dump(payload), success: true) do
      result = @executor.run
      assert_equal({ 'status' => 'already_done' }, result)
    end
    assert_equal [{ pr_number: 42, merge_commit: 'deadbeefcafef00d' }], called
  end

  private

  def assert_match_pr(pr, task_id)
    assert @executor.send(:pr_matches_task?, pr, task_id),
           "expected PR #{pr.inspect} to match task_id #{task_id}"
  end

  def refute_match_pr(pr, task_id)
    refute @executor.send(:pr_matches_task?, pr, task_id),
           "expected PR #{pr.inspect} NOT to match task_id #{task_id}"
  end

  # Stubs Open3.capture2 only when called with `gh pr list ...`. Falls through
  # to the real implementation for any other capture2 invocation so we don't
  # accidentally block git commands etc.
  def stub_gh_pr_list(stdout:, success:)
    fake_status = success ? FakeStatus.new(true) : FakeStatus.new(false)
    original = Open3.method(:capture2)
    Open3.define_singleton_method(:capture2) do |*args, **kw|
      if args.first == 'gh' && args[1] == 'pr' && args[2] == 'list'
        [stdout, fake_status]
      else
        original.call(*args, **kw)
      end
    end
    yield
  ensure
    Open3.singleton_class.send(:remove_method, :capture2) rescue nil
    Open3.define_singleton_method(:capture2, original) if original
  end

  FakeStatus = Struct.new(:ok) do
    def success? = ok
    def exitstatus = ok ? 0 : 1
  end
end
