# frozen_string_literal: true

require_relative 'auto_squash_base'

module WvRunner
  module ClaudeCode
    # Processes tasks from @next queue with automatic PR squash-merge after CI passes
    # Runs continuously 24/7 without quota checks or time limits
    class QueueAutoSquash < AutoSquashBase
      def model_name = "opusplan"

      private

      def build_instructions
        project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'

        <<~INSTRUCTIONS
          [PERSONA]
          You are a senior Ruby On Rails software developer, following RubyWay principles.

          [TASK]
          Work on the next available task with AUTOMATIC PR merge after CI passes.
          This is QUEUE mode - runs continuously 24/7 without quota checks.

          WORKFLOW:
          1. GIT STATE CHECK: Ensure you start from main branch
             - Run: git checkout main && git pull
             - This ensures you start from a clean, stable state

          2. TASK FETCH: Get the next available task
             - Read: workvector://pieces/jchsoft/@next?project_relative_id=#{project_id}
             - If no tasks available: STOP and output status "no_more_tasks"
             - Verify task is NOT already started or completed
             - DISPLAY TASK INFO: After loading, output in this exact format:
               WVRUNNER_TASK_INFO:
               ID: <relative_id>
               TITLE: <task name>
               DESCRIPTION: <first 200 chars of description, or full if shorter>
               END_TASK_INFO

          #{implementation_steps(start: 3)}
          #{ci_run_and_merge_step(step_num: 13, next_step: 14)}
          14. FINAL OUTPUT: Generate the result JSON

          IMPORTANT: This is QUEUE AUTO-SQUASH workflow - no quota checks, runs 24/7!
          PR is automatically merged after CI passes. If CI fails twice, PR stays open and runner stops.

          At the END, output JSON in this exact format - on a new line in a code block:

          ```json
          WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}}
          ```

          CRITICAL FORMATTING:
          1. The JSON MUST be inside triple backticks (```json ... ```) on a separate line
          2. Output VALID JSON with proper string escaping. Any quotes in string values must be escaped as \\"
          3. NO other text after the closing triple backticks

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
