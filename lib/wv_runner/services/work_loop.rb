# frozen_string_literal: true

module WvRunner
  # WorkLoop orchestrates Claude Code execution with different modes (once, today, daily)
  # and handles task scheduling with quota management and waiting strategies
  class WorkLoop
    VALID_HOW_VALUES = %i[once today daily once_dry].freeze

    def execute(how)
      puts "[WorkLoop] [execute] Starting execution with mode: #{how.inspect}"
      validate_how(how)
      puts "[WorkLoop] [execute] Mode validated successfully: #{how.inspect}"
      puts "[WorkLoop] [execute] Calling run_#{how}..."

      send("run_#{how}").tap { |result| puts "[WorkLoop] [execute] Execution complete, result: #{result.inspect}" }
    end

    private

    def run_once
      puts '[WorkLoop] [run_once] Starting single task execution...'
      result = ClaudeCode.new.run
      puts "[WorkLoop] [run_once] Single task completed with status: #{result['status']}"
      puts "[WorkLoop] [run_once] Full result: #{result.inspect}"
      result
    end

    def run_once_dry
      puts '[WorkLoop] [run_once_dry] Starting dry-run task load (no execution)...'
      result = ClaudeCode.new.run_dry
      puts "[WorkLoop] [run_once_dry] Dry-run completed with status: #{result['status']}"
      puts "[WorkLoop] [run_once_dry] Full result: #{result.inspect}"
      result
    end

    def run_today
      puts "[WorkLoop] [run_today] Starting today's task execution loop..."
      results = []
      iteration_count = 0

      loop do
        iteration_count += 1
        puts "[WorkLoop] [run_today] Starting iteration ##{iteration_count}..."
        run_task_iteration(results)

        decider = Decider.new(task_results: results)
        remaining = decider.remaining_hours
        puts "[WorkLoop] [run_today] After iteration ##{iteration_count}: remaining hours = #{remaining}h, total completed = #{results.length} tasks"

        if should_stop_running_today?(results)
          puts '[WorkLoop] [run_today] Stopping - decision made to stop running today (end of day or quota reached)'
          break
        end

        puts '[WorkLoop] [run_today] Continuing to next iteration, sleeping 2 seconds...'
        sleep(2)
      end

      puts "[WorkLoop] [run_today] Today's execution complete, total tasks: #{results.length}"
      results
    end

    def run_task_iteration(results)
      puts '[WorkLoop] [run_task_iteration] Running ClaudeCode for next task...'
      result = ClaudeCode.new.run
      results << result
      puts "[WorkLoop] [run_task_iteration] Task completed with status: #{result['status']}"
      puts "[WorkLoop] [run_task_iteration] Task result: #{result.inspect}"
    end

    def should_stop_running_today?(results)
      puts '[WorkLoop] [should_stop_running_today?] Checking if should stop...'
      is_end_of_day = end_of_day?
      puts "[WorkLoop] [should_stop_running_today?] End of day check: #{is_end_of_day} (current hour: #{Time.now.hour})"

      decider = Decider.new(task_results: results)
      should_stop_by_decider = decider.should_stop?
      puts "[WorkLoop] [should_stop_running_today?] Decider says stop: #{should_stop_by_decider}"

      should_stop = is_end_of_day || should_stop_by_decider
      puts "[WorkLoop] [should_stop_running_today?] Final decision: stop = #{should_stop}"
      should_stop
    end

    def run_daily
      puts '[WorkLoop] [run_daily] Starting daily execution loop...'
      day_count = 0

      loop do
        day_count += 1
        puts "[WorkLoop] [run_daily] Starting day ##{day_count}..."
        wait_if_cannot_work_today
        daily_results = run_today_tasks
        puts "[WorkLoop] [run_daily] Day ##{day_count} completed with #{daily_results.length} tasks"
        handle_daily_completion(daily_results)
      end
    end

    def wait_if_cannot_work_today
      puts '[WorkLoop] [wait_if_cannot_work_today] Checking if can work today...'
      can_work = DailyScheduler.new(task_results: []).can_work_today?
      puts "[WorkLoop] [wait_if_cannot_work_today] Can work today: #{can_work}"

      if can_work
        puts '[WorkLoop] [wait_if_cannot_work_today] OK to work, proceeding...'
        return
      end

      puts '[WorkLoop] [wait_if_cannot_work_today] Cannot work today (quota is 0 or weekend), waiting until next business day...'
      WaitingStrategy.new.wait_until_next_day
    end

    def run_today_tasks
      puts "[WorkLoop] [run_today_tasks] Starting today's tasks loop..."
      results = []
      iteration_count = 0

      loop do
        iteration_count += 1
        puts "[WorkLoop] [run_today_tasks] Iteration ##{iteration_count}..."
        run_task_iteration(results)

        if no_tasks_available?(results.last)
          puts "[WorkLoop] [run_today_tasks] No tasks available in iteration ##{iteration_count}"
          if handle_no_tasks_error(results)
            puts '[WorkLoop] [run_today_tasks] Retrying after no tasks error...'
            next
          end
        end

        if should_stop_running_today?(results)
          puts "[WorkLoop] [run_today_tasks] Stopping today's tasks"
          break
        end

        remaining = Decider.new(task_results: results).remaining_hours
        puts "[WorkLoop] [run_today_tasks] End of iteration ##{iteration_count}: remaining hours = #{remaining}h, sleeping 2 seconds..."
        sleep(2)
      end

      puts "[WorkLoop] [run_today_tasks] Today's tasks complete, total: #{results.length} tasks"
      results
    end

    def handle_no_tasks_error(_results)
      puts '[WorkLoop] [handle_no_tasks_error] No tasks available, waiting 1 hour before retry...'
      WaitingStrategy.new.wait_one_hour
      puts '[WorkLoop] [handle_no_tasks_error] Wait complete, ready to retry'
      true
    end

    def handle_daily_completion(daily_results)
      puts "[WorkLoop] [handle_daily_completion] Processing daily completion with #{daily_results.length} tasks..."
      scheduler = DailyScheduler.new(task_results: daily_results)

      if scheduler.should_continue_working?
        puts '[WorkLoop] [handle_daily_completion] Daily quota not exceeded, continuing to next day...'
      else
        puts '[WorkLoop] [handle_daily_completion] Daily quota exceeded (or scheduler says wait), waiting until next day...'
        WaitingStrategy.new.wait_until_next_day
      end
    end

    def no_tasks_available?(result)
      is_no_tasks = result['status'] == 'error' && result['message']&.include?('No tasks')
      puts "[WorkLoop] [no_tasks_available?] Checking result - status: #{result['status']}, message: #{result['message']&.truncate(100)}, is_no_tasks: #{is_no_tasks}"
      is_no_tasks
    end

    def end_of_day?
      hour = Time.now.hour
      is_end = hour >= 23
      puts "[WorkLoop] [end_of_day?] Current hour: #{hour}, is_end_of_day: #{is_end}"
      is_end
    end

    def validate_how(how)
      puts "[WorkLoop] [validate_how] Validating mode: #{how.inspect} against valid values: #{VALID_HOW_VALUES.inspect}"
      return if VALID_HOW_VALUES.include?(how)

      puts "[WorkLoop] [validate_how] INVALID mode: #{how.inspect}"
      raise ArgumentError, "Invalid 'how' value: #{how}. Must be one of: #{VALID_HOW_VALUES.join(', ')}"
    end
  end
end
