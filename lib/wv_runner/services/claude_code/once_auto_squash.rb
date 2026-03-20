# frozen_string_literal: true

require_relative 'auto_squash_base'

module WvRunner
  module ClaudeCode
    # Processes a single task with automatic PR squash-merge after CI passes
    # Unlike queue_auto_squash, this runs exactly once and exits
    class OnceAutoSquash < AutoSquashBase
      def initialize(verbose: false, model_override: nil, task_id: nil, resuming: false)
        super(verbose: verbose, model_override: model_override, resuming: resuming)
        @task_id = task_id
      end

      def model_name = "opus"

      private

      def task_fetch_url
        if @task_id
          "workvector://pieces/jchsoft/#{@task_id}"
        else
          project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'
          "workvector://pieces/jchsoft/@next?project_relative_id=#{project_id}"
        end
      end

      def build_instructions
        project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'
        fetch_url = task_fetch_url

        <<~INSTRUCTIONS
          [PERSONA]
          You are a senior Ruby On Rails software developer, following RubyWay principles.

          [TASK]
          Work on the next available task with AUTOMATIC PR merge after CI passes.
          This is ONCE mode - runs exactly once and exits after completing one task.

          WORKFLOW:
          #{@task_id ? triaged_git_step(resuming: @resuming) : branch_resume_check_step(project_id: project_id, pull_on_main: true)}

          2. TASK FETCH: Get the next available task
             - Read: #{fetch_url}
             - If no tasks available: STOP and output status "no_more_tasks"
             - Verify task is NOT already started or completed
             - DISPLAY TASK INFO: After loading, output in this exact format:
               WVRUNNER_TASK_INFO:
               ID: <relative_id>
               TITLE: <task name>
               DESCRIPTION: <first 200 chars of description, or full if shorter>
               END_TASK_INFO

          #{implementation_steps(start: 3)}
          #{ci_run_and_merge_step(step_num: 14, next_step: 15)}
          15. FINAL OUTPUT: Generate the result JSON

          IMPORTANT: This is ONCE AUTO-SQUASH workflow - runs exactly once and exits!
          PR is automatically merged after CI passes. If CI fails twice, PR stays open.

          #{result_format_instruction(
            '"status": "success", "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}'
          )}

          How to get the data:
          1. Read workvector://user -> use "hour_goal" for per_day, use "worked_out" for already_worked
             IMPORTANT: Read workvector://user at the very BEGINNING of the task before logging any work progress
          2. From the task you're working on -> parse "duration_best" field (e.g., "1 hodina" -> 1.0) for task_estimated
          3. Set status:
             - "success" if task completed and PR merged successfully
             - "no_more_tasks" if no tasks available (workvector returns "No available tasks found")
             - "ci_failed" if CI failed after retry (PR stays open)
             - "failure" for other errors
        INSTRUCTIONS
      end
    end
  end
end
