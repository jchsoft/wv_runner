# frozen_string_literal: true

require 'test_helper'
require_relative 'triage_test_helper'

class WorkLoopTriageTest < Minitest::Test
  include TriageTestHelper

  def test_extract_triage_model_maps_opus_to_opusplan
    loop_instance = WvRunner::WorkLoop.new
    result = loop_instance.send(:extract_triage_model, { 'recommended_model' => 'opus' })
    assert_equal 'opusplan', result
  end

  def test_extract_triage_model_maps_sonnet_to_sonnet
    loop_instance = WvRunner::WorkLoop.new
    result = loop_instance.send(:extract_triage_model, { 'recommended_model' => 'sonnet' })
    assert_equal 'sonnet', result
  end

  def test_extract_triage_model_defaults_to_opusplan_for_unknown
    loop_instance = WvRunner::WorkLoop.new
    result = loop_instance.send(:extract_triage_model, { 'recommended_model' => 'haiku' })
    assert_equal 'opusplan', result
  end

  def test_extract_triage_model_defaults_to_opusplan_for_nil
    loop_instance = WvRunner::WorkLoop.new
    result = loop_instance.send(:extract_triage_model, { 'recommended_model' => nil })
    assert_equal 'opusplan', result
  end

  def test_triage_no_more_tasks_short_circuits
    no_tasks_mock = Object.new
    def no_tasks_mock.run
      { 'status' => 'no_more_tasks', 'recommended_model' => 'opus' }
    end

    executor_called = false
    executor_mock = Object.new
    executor_mock.define_singleton_method(:run) do
      executor_called = true
      { 'status' => 'success' }
    end

    WvRunner::ClaudeCode::Triage.stub(:new, no_tasks_mock) do
      WvRunner::ClaudeCode::Honest.stub(:new, executor_mock) do
        loop_instance = WvRunner::WorkLoop.new
        result = loop_instance.execute(:once)

        assert_equal 'no_more_tasks', result['status']
        refute executor_called, 'Executor should not be called when triage returns no_more_tasks'
      end
    end
  end

  def test_triage_passes_model_override_to_executor
    triage_result_mock = Object.new
    def triage_result_mock.run
      { 'status' => 'success', 'recommended_model' => 'sonnet', 'task_id' => 999,
        'hours' => { 'per_day' => 8, 'task_estimated' => 1, 'already_worked' => 0 } }
    end

    received_kwargs = nil
    executor_mock = Object.new
    def executor_mock.run
      { 'status' => 'success', 'hours' => { 'per_day' => 8, 'task_estimated' => 1 } }
    end

    WvRunner::ClaudeCode::Triage.stub(:new, triage_result_mock) do
      WvRunner::ClaudeCode::OnceAutoSquash.stub(:new, ->(** kwargs) { received_kwargs = kwargs; executor_mock }) do
        loop_instance = WvRunner::WorkLoop.new
        loop_instance.execute(:once_auto_squash)

        assert_equal 'sonnet', received_kwargs[:model_override]
        assert_equal 999, received_kwargs[:task_id]
      end
    end
  end
end
