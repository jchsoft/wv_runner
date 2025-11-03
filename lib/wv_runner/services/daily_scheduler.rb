# frozen_string_literal: true

module WvRunner
  # DailyScheduler checks working day availability and quota management for daily task execution
  class DailyScheduler
    def initialize(task_results: [])
      @task_results = task_results.is_a?(Hash) ? [task_results] : task_results
    end

    def can_work_today?
      # If no results, we haven't run yet, so assume we can work
      return true if @task_results.empty?

      daily_hour_goal.positive?
    end

    def should_continue_working?
      !quota_exceeded?
    end

    def wait_reason
      return :zero_quota if daily_hour_goal <= 0
      return :quota_exceeded if quota_exceeded?

      nil
    end

    private

    def quota_exceeded?
      return false if @task_results.empty?

      remaining_hours <= 0
    end

    def remaining_hours
      return 0 if @task_results.empty?

      (daily_hour_goal - total_hours_worked).round(2)
    end

    def daily_hour_goal
      return 0 if @task_results.empty?

      @task_results.first.dig('hours', 'per_day').to_f
    end

    def total_hours_worked
      @task_results.sum { |r| r.dig('hours', 'task_worked').to_f }
    end
  end
end
