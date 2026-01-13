# frozen_string_literal: true

module WvRunner
  # WorkLoop orchestrates Claude Code execution with different modes (once, today, daily)
  # and handles task scheduling with quota management and waiting strategies
  class WorkLoop
    VALID_HOW_VALUES = %i[once today daily once_dry review reviews].freeze

    def initialize(verbose: false)
      @verbose = verbose
    end

    def execute(how)
      Logger.debug("[WorkLoop] [execute] Starting execution with mode: #{how.inspect}")
      validate_how(how)
      Logger.debug("[WorkLoop] [execute] Mode validated successfully: #{how.inspect}")
      Logger.debug("[WorkLoop] [execute] Calling run_#{how}...")

      send("run_#{how}").tap do |result|
        Logger.debug("[WorkLoop] [execute] Execution complete, result: #{result.inspect}")
      end
    end

    private

    def run_once
      Logger.debug('[WorkLoop] [run_once] Starting single task execution...')
      result = ClaudeCode::Honest.new(verbose: @verbose).run
      Logger.info_stdout("[WorkLoop] Task completed with status: #{result['status']}")
      Logger.debug("[WorkLoop] [run_once] Full result: #{result.inspect}")
      result
    end

    def run_once_dry
      Logger.debug('[WorkLoop] [run_once_dry] Starting dry-run task load (no execution)...')
      result = ClaudeCode::Dry.new(verbose: @verbose).run
      Logger.info_stdout("[WorkLoop] Dry-run completed with status: #{result['status']}")
      Logger.debug("[WorkLoop] [run_once_dry] Full result: #{result.inspect}")
      result
    end

    def run_review
      Logger.debug('[WorkLoop] [run_review] Starting PR review handling...')
      result = ClaudeCode::Review.new(verbose: @verbose).run
      Logger.info_stdout("[WorkLoop] Review completed with status: #{result['status']}")
      Logger.debug("[WorkLoop] [run_review] Full result: #{result.inspect}")
      result
    end

    def run_reviews
      Logger.debug('[WorkLoop] [run_reviews] Starting multiple PR reviews loop...')
      results = []
      iteration_count = 0

      loop do
        iteration_count += 1
        Logger.debug("[WorkLoop] [run_reviews] Starting iteration ##{iteration_count}...")
        result = ClaudeCode::Reviews.new(verbose: @verbose).run
        results << result
        Logger.info_stdout("[WorkLoop] Review ##{iteration_count} completed with status: #{result['status']}")

        break if result['status'] == 'no_reviews'
        break if result['status'] == 'failure'

        Logger.debug('[WorkLoop] [run_reviews] Continuing to next review, sleeping 2 seconds...')
        sleep(2)
      end

      Logger.info_stdout("[WorkLoop] Reviews loop complete, total processed: #{results.length}")
      results
    end

    def run_today
      Logger.debug("[WorkLoop] [run_today] Starting today's task execution loop...")
      results = []
      iteration_count = 0

      loop do
        iteration_count += 1
        Logger.debug("[WorkLoop] [run_today] Starting iteration ##{iteration_count}...")
        run_task_iteration(results)

        # Exit immediately when no more tasks available
        if no_tasks_available?(results.last)
          Logger.info_stdout('[WorkLoop] No more tasks available, ending today mode')
          break
        end

        decider = Decider.new(task_results: results)
        remaining = decider.remaining_hours
        Logger.debug("[WorkLoop] [run_today] After iteration ##{iteration_count}: remaining hours = #{remaining}h, total completed = #{results.length} tasks")

        if should_stop_running_today?(results)
          Logger.info_stdout('[WorkLoop] Stopping - end of day or quota reached')
          break
        end

        Logger.debug('[WorkLoop] [run_today] Continuing to next iteration, sleeping 2 seconds...')
        sleep(2)
      end

      Logger.info_stdout("[WorkLoop] Today's execution complete, total tasks: #{results.length}")
      results
    end

    def run_task_iteration(results)
      Logger.debug('[WorkLoop] [run_task_iteration] Running ClaudeCode::Honest for next task...')
      result = ClaudeCode::Honest.new(verbose: @verbose).run
      results << result
      Logger.debug("[WorkLoop] [run_task_iteration] Task completed with status: #{result['status']}")
      Logger.debug("[WorkLoop] [run_task_iteration] Task result: #{result.inspect}")
    end

    def should_stop_running_today?(results)
      Logger.debug('[WorkLoop] [should_stop_running_today?] Checking if should stop...')
      is_end_of_day = end_of_day?
      Logger.debug("[WorkLoop] [should_stop_running_today?] End of day check: #{is_end_of_day} (current hour: #{Time.now.hour})")

      decider = Decider.new(task_results: results)
      should_stop_by_decider = decider.should_stop?
      Logger.debug("[WorkLoop] [should_stop_running_today?] Decider says stop: #{should_stop_by_decider}")

      should_stop = is_end_of_day || should_stop_by_decider
      Logger.debug("[WorkLoop] [should_stop_running_today?] Final decision: stop = #{should_stop}")
      should_stop
    end

    def run_daily
      Logger.info_stdout('[WorkLoop] Starting daily execution loop...')
      day_count = 0

      loop do
        day_count += 1
        Logger.debug("[WorkLoop] [run_daily] Starting day ##{day_count}...")
        wait_if_cannot_work_today
        daily_results = run_today_tasks
        Logger.info_stdout("[WorkLoop] Day ##{day_count} completed with #{daily_results.length} tasks")
        handle_daily_completion(daily_results)
      end
    end

    def wait_if_cannot_work_today
      Logger.debug('[WorkLoop] [wait_if_cannot_work_today] Checking if can work today...')
      can_work = DailyScheduler.new(task_results: []).can_work_today?
      Logger.debug("[WorkLoop] [wait_if_cannot_work_today] Can work today: #{can_work}")

      if can_work
        Logger.debug('[WorkLoop] [wait_if_cannot_work_today] OK to work, proceeding...')
        return
      end

      Logger.info_stdout('[WorkLoop] Cannot work today (quota is 0 or weekend), waiting until next business day...')
      WaitingStrategy.new.wait_until_next_day
    end

    def run_today_tasks
      Logger.debug("[WorkLoop] [run_today_tasks] Starting today's tasks loop...")
      results = []
      iteration_count = 0

      loop do
        iteration_count += 1
        Logger.debug("[WorkLoop] [run_today_tasks] Iteration ##{iteration_count}...")
        run_task_iteration(results)

        if no_tasks_available?(results.last)
          Logger.info_stdout('[WorkLoop] No tasks available, will wait 1 hour before retry...')
          break unless handle_no_tasks_in_daily_mode
          Logger.debug('[WorkLoop] [run_today_tasks] Retrying after wait...')
          next
        end

        if should_stop_running_today?(results)
          Logger.debug("[WorkLoop] [run_today_tasks] Stopping today's tasks")
          break
        end

        remaining = Decider.new(task_results: results).remaining_hours
        Logger.debug("[WorkLoop] [run_today_tasks] End of iteration ##{iteration_count}: remaining hours = #{remaining}h, sleeping 2 seconds...")
        sleep(2)
      end

      Logger.debug("[WorkLoop] [run_today_tasks] Today's tasks complete, total: #{results.length} tasks")
      results
    end

    def handle_no_tasks_in_daily_mode
      # Check if past end of workday (18:00) - don't retry, let it go to next day
      if end_of_workday?
        Logger.info_stdout('[WorkLoop] Past end of workday (18:00), will resume tomorrow')
        return false
      end

      Logger.debug('[WorkLoop] [handle_no_tasks_in_daily_mode] Waiting 1 hour before retry...')
      WaitingStrategy.new.wait_one_hour

      # After waiting, check again if we're past workday end
      if end_of_workday?
        Logger.info_stdout('[WorkLoop] Now past end of workday (18:00), will resume tomorrow')
        return false
      end

      Logger.debug('[WorkLoop] [handle_no_tasks_in_daily_mode] Wait complete, ready to retry')
      true
    end

    def handle_daily_completion(daily_results)
      Logger.debug("[WorkLoop] [handle_daily_completion] Processing daily completion with #{daily_results.length} tasks...")
      scheduler = DailyScheduler.new(task_results: daily_results)

      if scheduler.should_continue_working?
        Logger.debug('[WorkLoop] [handle_daily_completion] Daily quota not exceeded, continuing to next day...')
      else
        Logger.info_stdout('[WorkLoop] Daily quota exceeded, waiting until next day...')
        WaitingStrategy.new.wait_until_next_day
      end
    end

    def no_tasks_available?(result)
      is_no_tasks = result['status'] == 'no_more_tasks'
      Logger.debug("[WorkLoop] [no_tasks_available?] Checking result - status: #{result['status']}, is_no_tasks: #{is_no_tasks}")
      is_no_tasks
    end

    def end_of_day?
      hour = Time.now.hour
      is_end = hour >= 23
      Logger.debug("[WorkLoop] [end_of_day?] Current hour: #{hour}, is_end_of_day: #{is_end}")
      is_end
    end

    def end_of_workday?
      hour = Time.now.hour
      is_end = hour >= 18
      Logger.debug("[WorkLoop] [end_of_workday?] Current hour: #{hour}, is_end_of_workday: #{is_end}")
      is_end
    end

    def validate_how(how)
      Logger.debug("[WorkLoop] [validate_how] Validating mode: #{how.inspect} against valid values: #{VALID_HOW_VALUES.inspect}")
      return if VALID_HOW_VALUES.include?(how)

      Logger.error("[WorkLoop] [validate_how] INVALID mode: #{how.inspect}")
      raise ArgumentError, "Invalid 'how' value: #{how}. Must be one of: #{VALID_HOW_VALUES.join(', ')}"
    end
  end
end
