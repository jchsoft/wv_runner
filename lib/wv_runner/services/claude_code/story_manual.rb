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
          [PERSONA]
          You are a senior Ruby On Rails software developer, following RubyWay principles.

          [TASK]
          Work on task ##{@task_id} from Story ##{@story_id}.

          #{time_awareness_instruction}

          #{coding_conventions_instruction}

          WORKFLOW:
          #{task_discovery_steps}

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

          How to get the data:
          1. Read workvector://user -> use "hour_goal" for per_day, use "worked_out" for already_worked
             IMPORTANT: Read workvector://user at the very BEGINNING of the task before logging any work progress
          2. From the task you're working on -> parse "duration_best" field (e.g., "1 hodina" -> 1.0) for task_estimated
          3. task_id: relative_id of the task you worked on
          4. Set status:
             - "success" if task completed successfully (PR created, NOT merged)
             - "no_more_tasks" if no incomplete tasks in the Story
             - "failure" for other errors
        INSTRUCTIONS
      end

      def task_discovery_steps
        <<~STEPS.chomp
          1. LOAD STORY CONTEXT: Read the story to understand the bigger picture
                   - Read: workvector://pieces/jchsoft/#{@story_id}
                   - Review the story name, description, and subtasks list
                   - Understand the overall goal and how subtasks relate to each other
                   - Note which subtasks are already completed for context
                   - You will work on task ##{@task_id} (pre-selected by triage)

                2. LOAD TASK DETAILS: Get full task information
                   - Read: workvector://pieces/jchsoft/#{@task_id}
                   - If task is IN PROGRESS (progress > 0):
                     → This is a CONTINUATION - skip git checkout/branch creation (steps 3-4)
                     → Go directly to step 5 (IMPLEMENT TASK) and continue where it was left off
                   - If task is NEW (progress = 0): proceed normally with all steps
                   - DISPLAY TASK INFO: After loading, output in this exact format:
                     WVRUNNER_TASK_INFO:
                     ID: <relative_id>
                     TITLE: <task name>
                     DESCRIPTION: <first 200 chars of description, or full if shorter>
                     END_TASK_INFO
        STEPS
      end
    end
  end
end
