# frozen_string_literal: true

module WvRunner
  # DailyScheduler checks working day availability and quota management for daily task execution
  class DailyScheduler
    def initialize(task_results: [])
      puts "[DailyScheduler] [initialize] Initializing with #{task_results.length} task results"
      @task_results = task_results.is_a?(Hash) ? [task_results] : task_results
      puts "[DailyScheduler] [initialize] Normalized to array of #{@task_results.length} results"
    end

    def can_work_today?
      puts "[DailyScheduler] [can_work_today?] Checking if can work today..."
      if @task_results.empty?
        puts "[DailyScheduler] [can_work_today?] No task results yet, assuming can work"
        return true
      end

      goal = daily_hour_goal
      can_work = goal.positive?
      puts "[DailyScheduler] [can_work_today?] Daily hour goal: #{goal}h, can_work: #{can_work}"
      can_work
    end

    def should_continue_working?
      puts "[DailyScheduler] [should_continue_working?] Checking if should continue..."
      quota_ok = !quota_exceeded?
      puts "[DailyScheduler] [should_continue_working?] Quota exceeded: #{!quota_ok}, should_continue: #{quota_ok}"
      quota_ok
    end

    def wait_reason
      puts "[DailyScheduler] [wait_reason] Determining wait reason..."
      goal = daily_hour_goal
      exceeded = quota_exceeded?

      if goal <= 0
        puts "[DailyScheduler] [wait_reason] Reason: zero_quota (goal=#{goal})"
        return :zero_quota
      end

      if exceeded
        remaining = remaining_hours
        puts "[DailyScheduler] [wait_reason] Reason: quota_exceeded (remaining=#{remaining}h)"
        return :quota_exceeded
      end

      puts "[DailyScheduler] [wait_reason] No wait reason, nil"
      nil
    end

    private

    def quota_exceeded?
      puts "[DailyScheduler] [quota_exceeded?] Checking if quota exceeded..."
      return false if @task_results.empty?

      remaining = remaining_hours
      exceeded = remaining <= 0
      puts "[DailyScheduler] [quota_exceeded?] Remaining hours: #{remaining}h, exceeded: #{exceeded}"
      exceeded
    end

    def remaining_hours
      puts "[DailyScheduler] [remaining_hours] Calculating remaining hours..."
      return 0 if @task_results.empty?

      goal = daily_hour_goal
      worked = total_hours_worked
      remaining = (goal - worked).round(2)
      puts "[DailyScheduler] [remaining_hours] Daily goal: #{goal}h, Worked: #{worked}h, Remaining: #{remaining}h"
      remaining
    end

    def daily_hour_goal
      puts "[DailyScheduler] [daily_hour_goal] Getting daily hour goal..."
      return 0 if @task_results.empty?

      goal = @task_results.first.dig('hours', 'per_day').to_f
      puts "[DailyScheduler] [daily_hour_goal] Goal: #{goal}h"
      goal
    end

    def total_hours_worked
      puts "[DailyScheduler] [total_hours_worked] Summing hours from #{@task_results.length} tasks..."
      total = @task_results.sum { |r| r.dig('hours', 'task_worked').to_f }
      puts "[DailyScheduler] [total_hours_worked] Total hours: #{total}h"
      total
    end
  end
end
