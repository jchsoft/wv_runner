# frozen_string_literal: true

require_relative 'auto_squash_base'

module WvRunner
  module ClaudeCode
    # Processes tasks from a specific Story with automatic PR squash-merge after CI passes
    # Creates PRs for each task and automatically merges them after local CI passes
    class StoryAutoSquash < AutoSquashBase
      def initialize(story_id:, task_id:, skip_story_load: false, **options)
        super(**options)
        @story_id = story_id
        @task_id = task_id
        @skip_story_load = skip_story_load
      end

      def model_name = "opus"

      private

      def build_instructions
        <<~INSTRUCTIONS
          #{persona_instruction}

          [TASK]
          Work on task ##{@task_id} from Story ##{@story_id} with AUTOMATIC PR merge after CI passes.

          WORKFLOW:
          #{story_task_discovery_steps(story_id: @story_id, task_id: @task_id, skip_story_load: @skip_story_load)}

          3. GIT STATE CHECK: Ensure you start from main branch
             - Run: git checkout main && git pull
             - This ensures you start from a clean, stable state

          #{implementation_steps(start: 4)}
          #{ci_run_and_merge_step(step_num: 15, next_step: 16)}
          16. FINAL OUTPUT: Generate the result JSON

          IMPORTANT: This is an AUTO-SQUASH workflow - PR is automatically merged after CI passes!
          If CI fails twice, the PR stays open for manual review.

          #{result_format_instruction(
            %("status": "success", "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}, "story_id": #{@story_id}, "task_id": Z)
          )}

          #{hours_data_instruction}
          3. task_id: relative_id of the task you worked on
          4. Set status:
             - "success" if task completed and PR merged successfully
             - "no_more_tasks" if no incomplete tasks in the Story
             - "ci_failed" if CI failed after retry (PR stays open)
             - "preexisting_test_errors" if tests were already failing before your changes (urgent bug task created)
             - "failure" for other errors
        INSTRUCTIONS
      end
    end
  end
end
