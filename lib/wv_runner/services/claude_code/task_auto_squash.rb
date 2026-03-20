# frozen_string_literal: true

require_relative 'auto_squash_base'

module WvRunner
  module ClaudeCode
    # Processes a specific task by ID with automatic PR squash-merge after CI passes
    class TaskAutoSquash < AutoSquashBase
      def initialize(task_id:, verbose: false, model_override: nil, resuming: false)
        super(verbose: verbose, model_override: model_override, resuming: resuming)
        @task_id = task_id
      end

      def model_name = "opus"

      private

      def build_instructions
        <<~INSTRUCTIONS
          [PERSONA]
          You are a senior Ruby On Rails software developer, following RubyWay principles.

          [TASK]
          Work on the specific task ##{@task_id} with AUTOMATIC PR merge after CI passes.

          WORKFLOW:
          #{triaged_git_step(resuming: @resuming)}

          2. LOAD TASK: Get task details
             - Read: workvector://pieces/jchsoft/#{@task_id}
             - DISPLAY TASK INFO: After loading, output in this exact format:
               WVRUNNER_TASK_INFO:
               ID: <relative_id>
               TITLE: <task name>
               DESCRIPTION: <first 200 chars of description, or full if shorter>
               END_TASK_INFO

          #{implementation_steps(start: 3)}
          #{ci_run_and_merge_step(step_num: 14, next_step: 15)}
          15. FINAL OUTPUT: Generate the result JSON

          IMPORTANT: This is an AUTO-SQUASH workflow - PR is automatically merged after CI passes!
          If CI fails twice, the PR stays open for manual review.

          #{result_format_instruction(
            %("status": "success", "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}, "task_id": #{@task_id})
          )}

          How to get the data:
          1. Read workvector://user -> use "hour_goal" for per_day, use "worked_out" for already_worked
             IMPORTANT: Read workvector://user at the very BEGINNING of the task before logging any work progress
          2. From the task you're working on -> parse "duration_best" field (e.g., "1 hodina" -> 1.0) for task_estimated
          3. Set status:
             - "success" if task completed and PR merged successfully
             - "ci_failed" if CI failed after retry (PR stays open)
             - "failure" for other errors
        INSTRUCTIONS
      end
    end
  end
end
