module WvRunner
  class Decider
    def initialize(task_results: [])
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
      return 0 if @task_results.empty?

      daily_limit = daily_hour_goal
      hours_worked = total_hours_worked
      (daily_limit - hours_worked).round(2)
    end

    def summary
      {
        should_continue: should_continue?,
        remaining_hours: remaining_hours,
        tasks_completed: tasks_completed,
        tasks_failed: tasks_failed?,
        daily_limit: daily_hour_goal,
        total_worked: total_hours_worked
      }
    end

    private

    def tasks_failed?
      @task_results.any? { |r| r["status"] == "error" }
    end

    def daily_quota_exceeded?
      return false if @task_results.empty?
      remaining_hours <= 0
    end

    def daily_hour_goal
      return 0 if @task_results.empty?
      @task_results.first.dig("hours", "per_day").to_f
    end

    def total_hours_worked
      @task_results.sum { |r| r.dig("hours", "task_worked").to_f }
    end

    def tasks_completed
      @task_results.count { |r| r["status"] == "success" }
    end
  end
end
