# frozen_string_literal: true

require_relative 'approval_collector'

module WvRunner
  # WorkLoop orchestrates Claude Code execution with different modes (once, today, daily)
  # and handles task scheduling with quota management and waiting strategies
  class WorkLoop
    VALID_HOW_VALUES = %i[once today daily once_dry review reviews workflow story_manual story_auto_squash today_auto_squash queue_auto_squash queue_manual once_auto_squash task_manual task_auto_squash].freeze

    def initialize(verbose: false, story_id: nil, task_id: nil, ignore_quota: false)
      @verbose = verbose
      @story_id = story_id
      @task_id = task_id
      @ignore_quota = ignore_quota
    end

    def execute(how)
      Logger.debug("[WorkLoop] [execute] Starting execution with mode: #{how.inspect}")
      validate_how(how)
      Logger.debug("[WorkLoop] [execute] Mode validated successfully: #{how.inspect}")
      Logger.debug("[WorkLoop] [execute] Calling run_#{how}...")

      # Clear any previously collected approval commands
      ApprovalCollector.clear

      send("run_#{how}").tap do |result|
        Logger.debug("[WorkLoop] [execute] Execution complete, result: #{result.inspect}")
        # Print summary of commands that required approval
        ApprovalCollector.print_summary
      end
    end

    private

    def run_once
      Logger.debug('[WorkLoop] [run_once] Starting single task execution...')
      triage_and_execute(ClaudeCode::Honest)
    end

    def run_once_auto_squash
      Logger.debug('[WorkLoop] [run_once_auto_squash] Starting single task execution with auto-squash...')
      triage_and_execute(ClaudeCode::OnceAutoSquash)
    end

    def run_task_manual
      raise ArgumentError, 'task_id is required for task_manual mode' unless @task_id

      Logger.debug("[WorkLoop] [run_task_manual] Starting Task ##{@task_id} manual workflow...")
      triage_and_execute(ClaudeCode::TaskManual, task_id: @task_id)
    end

    def run_task_auto_squash
      raise ArgumentError, 'task_id is required for task_auto_squash mode' unless @task_id

      Logger.debug("[WorkLoop] [run_task_auto_squash] Starting Task ##{@task_id} auto-squash workflow...")
      triage_and_execute(ClaudeCode::TaskAutoSquash, task_id: @task_id)
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
        break if quota_exceeded?(results)

        Logger.debug('[WorkLoop] [run_reviews] Continuing to next review, sleeping 2 seconds...')
        sleep(2)
      end

      Logger.info_stdout("[WorkLoop] Reviews loop complete, total processed: #{results.length}")
      results
    end

    def run_workflow
      Logger.debug('[WorkLoop] [run_workflow] Starting workflow: reviews then tasks...')
      workflow_results = { 'reviews' => [], 'tasks' => [] }

      Logger.info_stdout('[WorkLoop] Phase 1: Processing PR reviews...')
      workflow_results['reviews'] = run_reviews

      Logger.info_stdout('[WorkLoop] Phase 2: Processing tasks for today...')
      workflow_results['tasks'] = run_today

      Logger.info_stdout("[WorkLoop] Workflow complete: #{workflow_results['reviews'].length} reviews, #{workflow_results['tasks'].length} tasks")
      workflow_results
    end

    def run_story_manual
      raise ArgumentError, 'story_id is required for story_manual mode' unless @story_id

      Logger.debug("[WorkLoop] [run_story_manual] Starting Story ##{@story_id} manual workflow...")
      results = []
      iteration_count = 0

      loop do
        iteration_count += 1
        Logger.debug("[WorkLoop] [run_story_manual] Starting iteration ##{iteration_count}...")
        result = triage_and_execute(ClaudeCode::StoryManual, story_id: @story_id, skip_story_load: iteration_count > 1)
        results << result
        Logger.info_stdout("[WorkLoop] Task ##{iteration_count} completed with status: #{result['status']}")

        break if result['status'] == 'no_more_tasks'
        break if result['status'] == 'failure'
        break if result['status'] == 'task_already_started'
        break if result['status'] == 'quota_exceeded'
        break if quota_exceeded?(results)

        Logger.debug('[WorkLoop] [run_story_manual] Continuing to next task, sleeping 2 seconds...')
        sleep(2)
      end

      Logger.info_stdout("[WorkLoop] Story manual workflow complete, total tasks processed: #{results.length}")
      results
    end

    def run_story_auto_squash
      raise ArgumentError, 'story_id is required for story_auto_squash mode' unless @story_id

      Logger.debug("[WorkLoop] [run_story_auto_squash] Starting Story ##{@story_id} auto-squash workflow...")
      results = []
      iteration_count = 0

      loop do
        iteration_count += 1
        Logger.debug("[WorkLoop] [run_story_auto_squash] Starting iteration ##{iteration_count}...")
        result = triage_and_execute(ClaudeCode::StoryAutoSquash, story_id: @story_id, skip_story_load: iteration_count > 1)
        results << result
        status = result['status']
        Logger.info_stdout("[WorkLoop] Task ##{iteration_count} completed with status: #{status}")

        if status == 'preexisting_test_errors'
          Logger.info_stdout('[WorkLoop] Preexisting test errors detected, bug task created - continuing to next task...')
          sleep(2)
          next
        end

        break if %w[no_more_tasks failure task_already_started ci_failed quota_exceeded].include?(status)
        break if quota_exceeded?(results)

        Logger.debug('[WorkLoop] [run_story_auto_squash] Continuing to next task, sleeping 2 seconds...')
        sleep(2)
      end

      Logger.info_stdout("[WorkLoop] Story auto-squash workflow complete, total tasks processed: #{results.length}")
      results
    end

    def run_today_auto_squash
      Logger.debug('[WorkLoop] [run_today_auto_squash] Starting today auto-squash workflow...')
      results = []
      iteration_count = 0

      loop do
        iteration_count += 1
        Logger.debug("[WorkLoop] [run_today_auto_squash] Starting iteration ##{iteration_count}...")
        result = triage_and_execute(ClaudeCode::TodayAutoSquash)
        results << result
        status = result['status']
        Logger.info_stdout("[WorkLoop] Task ##{iteration_count} completed with status: #{status}")

        if status == 'no_more_tasks'
          if !@ignore_quota && triage_quota_exceeded?(result)
            Logger.info_stdout('[WorkLoop] Quota exceeded and no tasks available, stopping')
            break
          end
          break unless handle_no_tasks_in_today_auto_squash_mode

          next
        end
        if status == 'preexisting_test_errors'
          Logger.info_stdout('[WorkLoop] Preexisting test errors detected, bug task created - continuing to next task...')
          sleep(2)
          next
        end
        break if status == 'failure'
        break if status == 'ci_failed'
        break if status == 'quota_exceeded'
        break if quota_exceeded?(results)

        Logger.debug('[WorkLoop] [run_today_auto_squash] Continuing to next task, sleeping 2 seconds...')
        sleep(2)
      end

      Logger.info_stdout("[WorkLoop] Today auto-squash workflow complete, total tasks processed: #{results.length}")
      results
    end

    def run_queue_auto_squash
      Logger.debug('[WorkLoop] [run_queue_auto_squash] Starting queue auto-squash workflow...')
      results = []
      iteration_count = 0

      loop do
        iteration_count += 1
        Logger.debug("[WorkLoop] [run_queue_auto_squash] Starting iteration ##{iteration_count}...")
        result = triage_and_execute(ClaudeCode::QueueAutoSquash)
        results << result
        status = result['status']
        Logger.info_stdout("[WorkLoop] Task ##{iteration_count} completed with status: #{status}")

        if status == 'preexisting_test_errors'
          Logger.info_stdout('[WorkLoop] Preexisting test errors detected, bug task created - continuing to next task...')
          sleep(2)
          next
        end
        break if status == 'no_more_tasks'
        break if status == 'failure'
        break if status == 'ci_failed'
        break if status == 'quota_exceeded'
        break if quota_exceeded?(results)

        Logger.debug('[WorkLoop] [run_queue_auto_squash] Continuing to next task, sleeping 2 seconds...')
        sleep(2)
      end

      Logger.info_stdout("[WorkLoop] Queue auto-squash workflow complete, total tasks processed: #{results.length}")
      results
    end

    def run_queue_manual
      Logger.debug('[WorkLoop] [run_queue_manual] Starting queue manual workflow...')
      results = []
      iteration_count = 0

      loop do
        iteration_count += 1
        Logger.debug("[WorkLoop] [run_queue_manual] Starting iteration ##{iteration_count}...")
        result = triage_and_execute(ClaudeCode::Honest)
        results << result
        Logger.info_stdout("[WorkLoop] Task ##{iteration_count} completed with status: #{result['status']}")

        break if result['status'] == 'no_more_tasks'
        break if result['status'] == 'failure'
        break if result['status'] == 'quota_exceeded'
        break if quota_exceeded?(results)

        Logger.debug('[WorkLoop] [run_queue_manual] Continuing to next task, sleeping 2 seconds...')
        sleep(2)
      end

      Logger.info_stdout("[WorkLoop] Queue manual workflow complete, total tasks processed: #{results.length}")
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

        # Exit immediately when no more tasks available or quota exceeded before execution
        if no_tasks_available?(results.last) || results.last['status'] == 'quota_exceeded'
          Logger.info_stdout("[WorkLoop] #{results.last['status'] == 'quota_exceeded' ? 'Quota exceeded' : 'No more tasks available'}, ending today mode")
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
      result = triage_and_execute(ClaudeCode::Honest)
      results << result
      Logger.debug("[WorkLoop] [run_task_iteration] Task completed with status: #{result['status']}")
      Logger.debug("[WorkLoop] [run_task_iteration] Task result: #{result.inspect}")
    end

    def should_stop_running_today?(results)
      Logger.debug('[WorkLoop] [should_stop_running_today?] Checking if should stop...')
      is_end_of_day = end_of_day?
      Logger.debug("[WorkLoop] [should_stop_running_today?] End of day check: #{is_end_of_day} (current hour: #{Time.now.hour})")

      should_stop = is_end_of_day || quota_exceeded?(results)
      Logger.debug("[WorkLoop] [should_stop_running_today?] Final decision: stop = #{should_stop}")
      should_stop
    end

    def quota_exceeded?(results)
      if @ignore_quota
        Logger.debug('[WorkLoop] [quota_exceeded?] Quota check skipped (ignore_quota: true)')
        return false
      end

      decider = Decider.new(task_results: results)
      exceeded = decider.should_stop?
      Logger.debug("[WorkLoop] [quota_exceeded?] Decider says stop: #{exceeded}")

      if exceeded
        Logger.info_stdout('[WorkLoop] Quota exceeded, stopping')
      end

      exceeded
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

        if results.last['status'] == 'quota_exceeded'
          Logger.info_stdout('[WorkLoop] Quota exceeded before execution, stopping')
          break
        end

        if no_tasks_available?(results.last)
          if !@ignore_quota && triage_quota_exceeded?(results.last)
            Logger.info_stdout('[WorkLoop] Quota exceeded and no tasks available, stopping')
            break
          end
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

    def handle_no_tasks_in_today_auto_squash_mode
      # Check if past end of workday (18:00) - don't retry
      if end_of_workday?
        Logger.info_stdout('[WorkLoop] Past end of workday (18:00), stopping today auto-squash')
        return false
      end

      Logger.debug('[WorkLoop] [handle_no_tasks_in_today_auto_squash_mode] Waiting 30 minutes before retry...')
      WaitingStrategy.new.wait_half_hour

      # After waiting, check again if we're past workday end
      if end_of_workday?
        Logger.info_stdout('[WorkLoop] Now past end of workday (18:00), stopping today auto-squash')
        return false
      end

      Logger.debug('[WorkLoop] [handle_no_tasks_in_today_auto_squash_mode] Wait complete, ready to retry')
      true
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

    def triage_and_execute(executor_class, **kwargs)
      task_id_for_triage = kwargs[:task_id] || @task_id || detect_task_id_from_branch
      story_id_for_triage = kwargs[:story_id]

      Logger.info_stdout('[WorkLoop] Running triage to select optimal model...')
      triage_result = ClaudeCode::Triage.new(verbose: @verbose, task_id: task_id_for_triage, story_id: story_id_for_triage).run

      if triage_result['status'] == 'no_more_tasks'
        Logger.info_stdout('[WorkLoop] Triage: no tasks available')
        return triage_result
      end

      if triage_result['status'] == 'quota_exceeded'
        Logger.info_stdout('[WorkLoop] Triage reported quota exceeded')
        return { 'status' => 'quota_exceeded' }
      end

      if !@ignore_quota && triage_quota_exceeded?(triage_result)
        Logger.info_stdout('[WorkLoop] Quota already exceeded before execution, skipping task')
        return { 'status' => 'quota_exceeded' }
      end

      model_override = extract_triage_model(triage_result)
      triaged_task_id = triage_result['task_id']
      explicit_task_id = kwargs[:task_id]
      resuming = triage_result['resuming'] == true

      unless triaged_task_id
        Logger.error('[WorkLoop] Triage did not return a task_id')
        return { 'status' => 'error', 'message' => 'Triage completed but no task_id returned' }
      end

      if explicit_task_id && triaged_task_id != explicit_task_id
        Logger.warn("[WorkLoop] Triage returned task_id #{triaged_task_id} but explicit task_id #{explicit_task_id} was requested, using explicit")
        triaged_task_id = explicit_task_id
      end

      Logger.info_stdout("[WorkLoop] Triage recommended model: #{model_override} (task_id: #{triaged_task_id}, resuming: #{resuming})")

      # Story detected from @next — switch to story loop
      if triage_result['piece_type'] == 'Story' && !kwargs[:story_id]
        story_id = triage_result['story_id']
        Logger.info_stdout("[WorkLoop] Story ##{story_id} detected from @next, switching to story loop")
        return run_story_loop(story_id, executor_class, model_override: model_override, first_task_id: triaged_task_id)
      end

      executor_kwargs = kwargs.merge(verbose: @verbose, model_override: model_override, resuming: resuming)
      executor_kwargs[:task_id] = triaged_task_id if triaged_task_id

      result = executor_class.new(**executor_kwargs).run
      Logger.info_stdout("[WorkLoop] Task completed with status: #{result['status']}")
      Logger.debug("[WorkLoop] Full result: #{result.inspect}")
      result
    end

    def run_story_loop(story_id, original_executor_class, model_override: nil, first_task_id: nil)
      story_executor = story_executor_for(original_executor_class)
      Logger.info_stdout("[WorkLoop] Story loop: using #{story_executor.name} (mapped from #{original_executor_class.name})")
      results = []
      iteration_count = 0

      loop do
        iteration_count += 1
        Logger.debug("[WorkLoop] [run_story_loop] Story ##{story_id}, iteration ##{iteration_count}...")

        # First iteration — triage already found the subtask, execute directly
        # Subsequent iterations — re-triage to find next incomplete subtask, skip story re-fetch
        result = if iteration_count == 1 && first_task_id
          story_executor.new(story_id: story_id, task_id: first_task_id, verbose: @verbose, model_override: model_override).run
        else
          triage_and_execute(story_executor, story_id: story_id, skip_story_load: true)
        end

        results << result
        status = result['status']
        Logger.info_stdout("[WorkLoop] Story loop task ##{iteration_count} completed with status: #{status}")

        if status == 'preexisting_test_errors'
          Logger.info_stdout('[WorkLoop] Preexisting test errors in story loop, continuing to next task...')
          sleep(2)
          next
        end

        break if %w[no_more_tasks failure task_already_started ci_failed quota_exceeded].include?(status)
        break if quota_exceeded?(results)

        sleep(2)
      end

      Logger.info_stdout("[WorkLoop] Story loop complete for Story ##{story_id}, total tasks: #{results.length}")
      results.last || { 'status' => 'no_more_tasks' }
    end

    STORY_EXECUTOR_MAP = {
      ClaudeCode::Honest => ClaudeCode::StoryManual,
      ClaudeCode::TodayAutoSquash => ClaudeCode::StoryAutoSquash,
      ClaudeCode::OnceAutoSquash => ClaudeCode::StoryAutoSquash,
      ClaudeCode::QueueAutoSquash => ClaudeCode::StoryAutoSquash
    }.freeze

    def story_executor_for(executor_class)
      STORY_EXECUTOR_MAP.fetch(executor_class) do
        Logger.warn("[WorkLoop] No story executor mapping for #{executor_class.name}, using StoryManual")
        ClaudeCode::StoryManual
      end
    end

    def detect_task_id_from_branch
      branch = `git branch --show-current 2>/dev/null`.strip
      return nil if branch.empty? || branch == 'main' || branch == 'master'

      match = branch.match(/(\d{4,})/)
      return nil unless match

      task_id = match[1].to_i
      Logger.info_stdout("[WorkLoop] Detected task ID #{task_id} from branch '#{branch}'")
      task_id
    end

    def triage_quota_exceeded?(triage_result)
      hours = triage_result['hours']
      return false unless hours

      per_day = hours['per_day'].to_f
      already_worked = hours['already_worked'].to_f
      exceeded = already_worked >= per_day
      Logger.debug("[WorkLoop] [triage_quota_exceeded?] per_day: #{per_day}h, already_worked: #{already_worked}h, exceeded: #{exceeded}")
      exceeded
    end

    def extract_triage_model(triage_result)
      recommended = triage_result['recommended_model']
      case recommended
      when 'sonnet', 'opus', 'haiku' then recommended
      else
        Logger.warn("[WorkLoop] Unknown triage model '#{recommended}', defaulting to opus")
        'opus'
      end
    end
  end
end
