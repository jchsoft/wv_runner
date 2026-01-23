# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Dry run - only loads and displays task information, no modifications
    class Dry < ClaudeCodeBase
      def model_name
        'haiku'
      end

      private

      def accept_edits?
        false # Dry run should not modify files
      end

      def build_instructions
        project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'

        <<~INSTRUCTIONS
          Load and display information about the next task from: workvector://pieces/jchsoft/@next?project_relative_id=#{project_id}

          WORKFLOW (DRY RUN - NO EXECUTION):
          1. Fetch the next task from WorkVector using the URL above
          2. DISPLAY TASK INFO: After loading, output in this exact format:
             WVRUNNER_TASK_INFO:
             ID: <relative_id>
             TITLE: <task name>
             DESCRIPTION: <first 200 chars of description, or full if shorter>
             END_TASK_INFO
          3. DO NOT create a branch
          4. DO NOT modify any code
          5. DO NOT create a pull request
          6. Just read and display the task information

          At the END, output JSON in this exact format - on a new line in a code block:

          [DEBUG] duration_best: '<original_value>' -> task_estimated: Y

          ```json
          WVRUNNER_RESULT: {"status": "success", "task_info": {"name": "...", "id": ..., "description": "...", "status": "...", "priority": "...", "assigned_user": "...", "scrum_points": "..."}, "hours": {"per_day": X, "task_estimated": Y}}
          ```

          CRITICAL FORMATTING:
          1. The JSON MUST be inside triple backticks (```json ... ```) on a separate line
          2. Output VALID JSON with proper string escaping. Any quotes in string values must be escaped as \\"
          3. NO other text after the closing triple backticks

          How to get the data:
          1. Read workvector://user -> use "hour_goal" value for per_day
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
