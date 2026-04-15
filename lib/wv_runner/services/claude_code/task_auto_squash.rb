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
          #{persona_instruction}

          [TASK]
          Work on the specific task ##{@task_id} with AUTOMATIC PR merge after CI passes.

          WORKFLOW:
          #{triaged_git_step(resuming: @resuming)}

          #{load_task_step(step_num: 2, task_id: @task_id)}

          #{implementation_steps(start: 3)}
          #{ci_run_and_merge_step(step_num: 14, next_step: 15)}
          15. FINAL OUTPUT: Generate the result JSON

          AUTO-SQUASH: PR auto-merged after CI. CI fails 2× → PR stays open.

          #{result_format_instruction(
            %("status": "success", "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}, "task_id": #{@task_id})
          )}

          #{hours_data_instruction}
          3. Set status:
             - "success" if task completed and PR merged successfully
             - "ci_failed" if CI failed after retry (PR stays open)
             - "preexisting_test_errors" if tests were already failing before your changes (urgent bug task created)
             - "failure" for other errors
        INSTRUCTIONS
      end
    end
  end
end
