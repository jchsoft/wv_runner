# frozen_string_literal: true

# Shared helper for WorkLoop tests that need triage mocking
module TriageTestHelper
  def triage_mock(task_id: 123, recommended_model: 'opus')
    mock = Object.new
    mock.define_singleton_method(:run) do
      { 'status' => 'success', 'recommended_model' => recommended_model, 'task_id' => task_id,
        'hours' => { 'per_day' => 8, 'task_estimated' => 2, 'already_worked' => 0 } }
    end
    mock
  end

  def with_triage_stub(**kwargs, &block)
    WvRunner::ClaudeCode::Triage.stub(:new, triage_mock(**kwargs), &block)
  end
end
