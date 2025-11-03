# frozen_string_literal: true

module WvRunner
  # WorkLoop orchestrates Claude Code execution with different modes (once, today, daily)
  # and handles task scheduling with quota management and waiting strategies
  class WorkLoop
    VALID_HOW_VALUES = %i[once today daily].freeze

    def execute(how)
      validate_how(how)
      puts "WorkLoop executing with mode: #{how}"
      send("run_#{how}")
    end

    private

    def run_once
      result = ClaudeCode.new.run
      puts "Task completed: #{result.inspect}"
      result
    end

    def run_today
      results = []
      loop do
        run_task_iteration(results)
        break if should_stop_running_today?(results)

        puts "Remaining hours today: #{Decider.new(task_results: results).remaining_hours}h"
        sleep(2)
      end
      results
    end

    def run_task_iteration(results)
      puts 'Running task iteration...'
      result = ClaudeCode.new.run
      results << result
      puts "Task result: #{result.inspect}"
    end

    def should_stop_running_today?(results)
      end_of_day? || Decider.new(task_results: results).should_stop?
    end

    def run_daily
      loop do
        wait_if_cannot_work_today
        daily_results = run_today_tasks
        handle_daily_completion(daily_results)
      end
    end

    def wait_if_cannot_work_today
      return if DailyScheduler.new(task_results: []).can_work_today?

      puts 'Daily quota is 0 or weekend detected, waiting until next business day...'
      WaitingStrategy.new.wait_until_next_day
    end

    def run_today_tasks
      results = []
      loop do
        run_task_iteration(results)
        handle_no_tasks_error(results) && next if no_tasks_available?(results.last)

        break if should_stop_running_today?(results)

        puts "Remaining hours today: #{Decider.new(task_results: results).remaining_hours}h"
        sleep(2)
      end
      results
    end

    def handle_no_tasks_error(_results)
      puts 'No tasks available, will retry after waiting...'
      WaitingStrategy.new.wait_one_hour
      true
    end

    def handle_daily_completion(daily_results)
      scheduler = DailyScheduler.new(task_results: daily_results)

      if scheduler.should_continue_working?
        puts 'Daily quota not exceeded, continuing with next day...'
      else
        puts 'Daily quota exceeded, waiting until next day...'
        WaitingStrategy.new.wait_until_next_day
      end
    end

    def no_tasks_available?(result)
      result['status'] == 'error' && result['message']&.include?('No tasks')
    end

    def end_of_day?
      Time.now.hour >= 23
    end

    def validate_how(how)
      return if VALID_HOW_VALUES.include?(how)

      raise ArgumentError, "Invalid 'how' value: #{how}. Must be one of: #{VALID_HOW_VALUES.join(', ')}"
    end
  end
end
