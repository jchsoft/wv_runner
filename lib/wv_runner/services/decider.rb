require 'json'

module WvRunner
  class Decider
    def initialize(user_info: nil, task_results: [])
      @user_info = user_info
      @task_results = task_results.is_a?(Hash) ? [task_results] : task_results
    end

    def should_continue?
      return false if tasks_failed?
      return false if daily_quota_exceeded?
      true
    end

    def should_stop?
      !should_continue?
    end

    def remaining_hours
      return 0 if !@user_info

      daily_limit = @user_info["hour_goal"].to_f
      hours_worked = @task_results.sum { |r| r.dig("hours", "task_worked").to_f }
      (daily_limit - hours_worked).round(2)
    end

    def summary
      {
        should_continue: should_continue?,
        remaining_hours: remaining_hours,
        tasks_completed: tasks_completed,
        tasks_failed: tasks_failed?
      }
    end

    private

    def tasks_failed?
      @task_results.any? { |r| r["status"] == "error" }
    end

    def daily_quota_exceeded?
      return false unless @user_info
      remaining_hours <= 0
    end

    def tasks_completed
      @task_results.count { |r| r["status"] == "success" }
    end
  end
end
