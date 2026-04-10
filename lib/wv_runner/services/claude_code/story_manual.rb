# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Processes tasks from a specific Story without auto-merge
    # Creates PRs for each task but leaves them open for human review
    class StoryManual < ClaudeCodeBase
      include WorkflowSteps

      def initialize(story_id:, task_id:, verbose: false, model_override: nil, resuming: false)
        super(verbose: verbose, model_override: model_override, resuming: resuming)
        @story_id = story_id
        @task_id = task_id
      end

      def model_name = "opus"

      private

      def build_instructions
        <<~INSTRUCTIONS
          #{persona_instruction}

          [TASK]
          Work on task ##{@task_id} from Story ##{@story_id}.

          #{time_awareness_instruction}

          #{coding_conventions_instruction}

          WORKFLOW:
          #{story_task_discovery_steps(story_id: @story_id, task_id: @task_id)}

          3. GIT STATE CHECK: Ensure you start from main branch
             - Run: git checkout main && git pull
             - This ensures you start from a clean, stable state

          #{create_branch_step(step_num: 4)}

          #{implement_task_step(step_num: 5)}

          #{run_unit_tests_step(step_num: 6)}

          #{prepare_screenshots_step(step_num: 7)}

          #{run_system_tests_step(step_num: 8)}

          #{refactor_step(step_num: 9)}

          #{verify_tests_step(step_num: 10)}

          #{push_step(step_num: 11)}

          #{create_pr_step(step_num: 12, no_merge_warning: true)}

          #{add_screenshots_to_pr_step(step_num: 13)}

          #{run_local_ci_step(step_num: 14, verify_step_ref: 10)}

          IMPORTANT: This is a MANUAL workflow - PR is created but NOT merged!
          Human will review and merge the PR manually.

          #{result_format_instruction(
            %("status": "success", "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}, "story_id": #{@story_id}, "task_id": Z)
          )}

          #{hours_data_instruction}
          3. task_id: relative_id of the task you worked on
          4. Set status:
             - "success" if task completed successfully (PR created, NOT merged)
             - "no_more_tasks" if no incomplete tasks in the Story
             - "failure" for other errors
        INSTRUCTIONS
      end
    end
  end
end
