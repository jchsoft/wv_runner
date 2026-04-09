# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Dry run - only loads and displays task information, no modifications
    class Dry < ClaudeCodeBase
      def model_name = "haiku"

      private

      def accept_edits?
        false # Dry run should not modify files
      end

      def build_instructions
        project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'

        <<~INSTRUCTIONS
          Load and display information about the next task from: workvector://pieces/jchsoft/@next?project_relative_id=#{project_id}

          WORKFLOW (DRY RUN - NO EXECUTION):
          1. Fetch the next piece from WorkVector using the URL above
          2. Check the "type" field:
             - If type is "Story": go to step 2b
             - If type is "Task": go to step 2c
          2b. STORY DETECTED:
             - Display story info (ID, TITLE, DESCRIPTION)
             - List ALL subtasks with their state and progress
             - Find first subtask where state is NOT "Schváleno" and NOT "Hotovo?" and progress < 100
             - If found: fetch that subtask via workvector://pieces/jchsoft/<subtask_relative_id> and display it too
             - Set piece_type to "Story" and story_id to the Story's relative_id in the result
             - Use the SUBTASK data for task_info in the result (not the Story)
          2c. DISPLAY TASK INFO: After loading, output in this exact format:
             WVRUNNER_TASK_INFO:
             ID: <relative_id>
             TITLE: <task name>
             DESCRIPTION: <first 200 chars of description, or full if shorter>
             END_TASK_INFO
          3. DO NOT create a branch
          4. DO NOT modify any code
          5. DO NOT create a pull request
          6. Just read and display the task information

          At the END, first output a debug line, then the result JSON:

          [DEBUG] duration_best: '<original_value>' -> task_estimated: Y

          #{result_format_instruction(
            '"status": "success", "piece_type": "Task", "story_id": null, "task_info": {"name": "...", "id": 123, "description": "...", "status": "...", "priority": "...", "assigned_user": "...", "scrum_points": "..."}, "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}'
          )}

          How to get the data:
          1. Read workvector://user -> use "hour_goal" for per_day, use "worked_out" for already_worked
             IMPORTANT: Read workvector://user at the very BEGINNING of the task before logging any work progress
             WARNING: "already_worked" is the DAILY worked hours from "worked_out" field (e.g. 3.0). Do NOT calculate it from task effort minutes or effort history!
          2. From the task you're working on -> extract: name, relative_id (as id), description, task_state (as status), priority, assigned_user, scrum_point (as scrum_points)
          3. For task_estimated: Extract "duration_best" field from the task data. Convert it to numeric hours:
             - If duration_best contains "hodina" or "hours" -> extract the number (e.g., "3 hodiny" -> 3.0)
             - If duration_best contains "den" or "day" -> multiply by 8 hours per workday (e.g., "1 den" -> 8.0)
             - If duration_best contains "tyden" or "week" -> multiply by 40 hours per workweek (e.g., "1 tyden" -> 40.0)
             - Use the smallest/first number as task_estimated (e.g., from "3.0 - 7.0 hodin", use 3.0)
          4. Set status: "success" if task loaded successfully
        INSTRUCTIONS
      end
    end
  end
end
