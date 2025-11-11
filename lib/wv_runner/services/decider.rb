# frozen_string_literal: true

module WvRunner
  class Decider
    def initialize(task_results: [])
      puts "[Decider] [initialize] Initializing with #{task_results.length} task results"
      @task_results = task_results.is_a?(Hash) ? [task_results] : task_results
      puts "[Decider] [initialize] Normalized to array of #{@task_results.length} results"
    end

    def should_continue?
      result = !should_stop?
      puts "[Decider] [should_continue?] Result: #{result}"
      result
    end

    def should_stop?
      puts '[Decider] [should_stop?] Checking stop conditions...'
      has_failures = tasks_failed?
      quota_exceeded = daily_quota_exceeded?

      puts "[Decider] [should_stop?] Tasks failed: #{has_failures}, quota exceeded: #{quota_exceeded}"

      should_stop_result = has_failures || quota_exceeded
      puts "[Decider] [should_stop?] Final decision: #{should_stop_result}"
      should_stop_result
    end

    def remaining_hours
      puts '[Decider] [remaining_hours] Calculating remaining hours...'

      if @task_results.empty?
        puts '[Decider] [remaining_hours] No task results, returning 0'
        return 0
      end

      daily_goal = daily_hour_goal
      total_worked = total_hours_estimated # Using estimated because we simulate human-like behavior
      remaining = (daily_goal - total_worked).round(2)

      puts "[Decider] [remaining_hours] Daily goal: #{daily_goal}h, Total worked: #{total_worked}h, Remaining: #{remaining}h"
      remaining
    end

    def summary
      puts '[Decider] [summary] Building summary...'
      summary_data = {
        should_continue: should_continue?,
        remaining_hours: remaining_hours,
        tasks_completed: tasks_completed,
        tasks_failed: tasks_failed?,
        daily_limit: daily_hour_goal,
        total_worked: total_hours_worked
      }
      puts "[Decider] [summary] Summary: #{summary_data.inspect}"
      summary_data
    end

    private

    def tasks_failed?
      failed_count = @task_results.count { |r| r['status'] == 'error' }
      has_failures = failed_count.positive?
      puts "[Decider] [tasks_failed?] Total results: #{@task_results.length}, Failed: #{failed_count}, has_failures: #{has_failures}"
      has_failures
    end

    def daily_quota_exceeded?
      puts '[Decider] [daily_quota_exceeded?] Checking daily quota...'
      return false if @task_results.empty?

      remaining = remaining_hours
      exceeded = remaining <= 0
      puts "[Decider] [daily_quota_exceeded?] Remaining hours: #{remaining}, quota exceeded: #{exceeded}"
      exceeded
    end

    def daily_hour_goal
      puts '[Decider] [daily_hour_goal] Calculating daily hour goal...'
      return 0 if @task_results.empty?

      goal = @task_results.first.dig('hours', 'per_day').to_f
      puts "[Decider] [daily_hour_goal] Daily hour goal: #{goal}h"
      goal
    end

    def total_hours_worked
      puts "[Decider] [total_hours_worked] Summing hours from #{@task_results.length} tasks..."
      total = @task_results.sum { |r| r.dig('hours', 'task_worked').to_f }
      puts "[Decider] [total_hours_worked] Total hours worked: #{total}h"
      total
    end

    def total_hours_estimated
      puts "[Decider] [total_hours_estimated] Summing hours from #{@task_results.length} tasks..."
      total = @task_results.sum { |r| r.dig('hours', 'task_estimated').to_f }
      puts "[Decider] [total_hours_estimated] Total hours estimated: #{total}h"
      total
    end

    def tasks_completed
      completed_count = @task_results.count { |r| r['status'] == 'success' }
      puts "[Decider] [tasks_completed] Tasks completed: #{completed_count} out of #{@task_results.length}"
      completed_count
    end
  end
end
