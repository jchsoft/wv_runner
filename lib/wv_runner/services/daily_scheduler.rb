# frozen_string_literal: true

module WvRunner
  # DailyScheduler checks working day availability and quota management for daily task execution
  class DailyScheduler
    def initialize(task_results: [])
      Logger.debug("[DailyScheduler] [initialize] Initializing with #{task_results.length} task results")
      @task_results = task_results.is_a?(Hash) ? [task_results] : task_results
      Logger.debug("[DailyScheduler] [initialize] Normalized to array of #{@task_results.length} results")
    end

    def can_work_today?
      Logger.debug("[DailyScheduler] [can_work_today?] Checking if can work today...")
      if @task_results.empty?
        Logger.debug("[DailyScheduler] [can_work_today?] No task results yet, assuming can work")
        return true
      end

      goal = daily_hour_goal
      can_work = goal.positive?
      Logger.debug("[DailyScheduler] [can_work_today?] Daily hour goal: #{goal}h, can_work: #{can_work}")
      can_work
    end

    def should_continue_working?
      Logger.debug("[DailyScheduler] [should_continue_working?] Checking if should continue...")
      quota_ok = !quota_exceeded?
      Logger.debug("[DailyScheduler] [should_continue_working?] Quota exceeded: #{!quota_ok}, should_continue: #{quota_ok}")
      quota_ok
    end

    def wait_reason
      Logger.debug("[DailyScheduler] [wait_reason] Determining wait reason...")
      goal = daily_hour_goal
      exceeded = quota_exceeded?

      if goal <= 0
        Logger.debug("[DailyScheduler] [wait_reason] Reason: zero_quota (goal=#{goal})")
        return :zero_quota
      end

      if exceeded
        remaining = remaining_hours
        Logger.debug("[DailyScheduler] [wait_reason] Reason: quota_exceeded (remaining=#{remaining}h)")
        return :quota_exceeded
      end

      Logger.debug("[DailyScheduler] [wait_reason] No wait reason, nil")
      nil
    end

    private

    def quota_exceeded?
      Logger.debug("[DailyScheduler] [quota_exceeded?] Checking if quota exceeded...")
      return false if @task_results.empty?

      remaining = remaining_hours
      exceeded = remaining <= 0
      Logger.debug("[DailyScheduler] [quota_exceeded?] Remaining hours: #{remaining}h, exceeded: #{exceeded}")
      exceeded
    end

    def remaining_hours
      Logger.debug("[DailyScheduler] [remaining_hours] Calculating remaining hours...")
      return 0 if @task_results.empty?

      goal = daily_hour_goal
      already = already_worked_before_session
      worked = total_hours_worked
      remaining = (goal - already - worked).round(2)
      Logger.debug("[DailyScheduler] [remaining_hours] Daily goal: #{goal}h, Already worked: #{already}h, Session worked: #{worked}h, Remaining: #{remaining}h")
      remaining
    end

    def daily_hour_goal
      Logger.debug("[DailyScheduler] [daily_hour_goal] Getting daily hour goal...")
      return 0 if @task_results.empty?

      goal = @task_results.first.dig('hours', 'per_day').to_f
      Logger.debug("[DailyScheduler] [daily_hour_goal] Goal: #{goal}h")
      goal
    end

    def total_hours_worked
      Logger.debug("[DailyScheduler] [total_hours_worked] Summing hours from #{@task_results.length} tasks...")
      total = @task_results.sum { |r| r.dig('hours', 'task_worked').to_f }
      Logger.debug("[DailyScheduler] [total_hours_worked] Total hours: #{total}h")
      total
    end

    def already_worked_before_session
      # Use only from the first task result — represents hours worked
      # before this wv_runner session started
      already = @task_results.first.dig('hours', 'already_worked').to_f
      Logger.debug("[DailyScheduler] [already_worked_before_session] Already worked before session: #{already}h")
      already
    end
  end
end
