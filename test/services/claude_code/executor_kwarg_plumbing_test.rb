# frozen_string_literal: true

require 'test_helper'
require 'mcptask_runner/snapshot_builder'
require 'mcptask_runner/services/claude_code/triage'
require 'mcptask_runner/services/claude_code/honest'
require 'mcptask_runner/services/claude_code/today_auto_squash'
require 'mcptask_runner/services/claude_code/once_auto_squash'
require 'mcptask_runner/services/claude_code/queue_auto_squash'
require 'mcptask_runner/services/claude_code/task_auto_squash'
require 'mcptask_runner/services/claude_code/task_manual'
require 'mcptask_runner/services/claude_code/story_auto_squash'
require 'mcptask_runner/services/claude_code/story_manual'

# Smoke test: every executor that triage_execution / loop_strategies instantiates
# must accept `snapshot_builder:` so the shared WorkLoop builder is wired through.
# This catches:
#   - 1.7.9 regression: subclasses with explicit kwarg lists rejecting :snapshot_builder
#   - 1.8.0 regression: run_story_loop forgetting to pass @builder to first-task executor
class ExecutorKwargPlumbingTest < Minitest::Test
  def setup
    @builder = McptaskRunner::SnapshotBuilder.new(session_id: 'sid', machine_id: 'mach')
  end

  # Classes that take no required positional/keyword args beyond standard ones.
  PLAIN_EXECUTORS = [
    McptaskRunner::ClaudeCode::Honest,
    McptaskRunner::ClaudeCode::TodayAutoSquash,
    McptaskRunner::ClaudeCode::OnceAutoSquash,
    McptaskRunner::ClaudeCode::QueueAutoSquash
  ].freeze

  TASK_ID_EXECUTORS = [
    McptaskRunner::ClaudeCode::TaskAutoSquash,
    McptaskRunner::ClaudeCode::TaskManual
  ].freeze

  STORY_EXECUTORS = [
    McptaskRunner::ClaudeCode::StoryAutoSquash,
    McptaskRunner::ClaudeCode::StoryManual
  ].freeze

  def test_triage_accepts_snapshot_builder_kwarg
    instance = McptaskRunner::ClaudeCode::Triage.new(task_id: 1, snapshot_builder: @builder)
    assert_same @builder, instance.instance_variable_get(:@snapshot_builder)
  end

  def test_plain_executors_accept_snapshot_builder_kwarg
    PLAIN_EXECUTORS.each do |klass|
      instance = klass.new(snapshot_builder: @builder)
      assert_same @builder, instance.instance_variable_get(:@snapshot_builder),
                  "#{klass.name} did not forward snapshot_builder to ClaudeCodeBase"
    end
  end

  def test_task_id_executors_accept_snapshot_builder_kwarg
    TASK_ID_EXECUTORS.each do |klass|
      instance = klass.new(task_id: 1, snapshot_builder: @builder)
      assert_same @builder, instance.instance_variable_get(:@snapshot_builder),
                  "#{klass.name} did not forward snapshot_builder to ClaudeCodeBase"
    end
  end

  def test_story_executors_accept_snapshot_builder_kwarg
    STORY_EXECUTORS.each do |klass|
      instance = klass.new(story_id: 1, task_id: 1, snapshot_builder: @builder)
      assert_same @builder, instance.instance_variable_get(:@snapshot_builder),
                  "#{klass.name} did not forward snapshot_builder to ClaudeCodeBase"
    end
  end
end
