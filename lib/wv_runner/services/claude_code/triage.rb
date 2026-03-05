# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Triage step - cheap Haiku call that analyzes task complexity
    # and recommends the optimal model for execution
    class Triage < ClaudeCodeBase
      def initialize(verbose: false, task_id: nil)
        super(verbose: verbose)
        @task_id = task_id
      end

      def model_name = "haiku"

      private

      def accept_edits?
        false
      end

      def task_fetch_url
        if @task_id
          "workvector://pieces/jchsoft/#{@task_id}"
        else
          project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'
          "workvector://pieces/jchsoft/@next?project_relative_id=#{project_id}"
        end
      end

      def build_instructions
        fetch_url = task_fetch_url

        <<~INSTRUCTIONS
          You are a task triage agent. Your ONLY job is to analyze a task and recommend which AI model should execute it.

          1. Fetch the task from: #{fetch_url}
          2. If no tasks available: output status "no_more_tasks" with recommended_model "opusplan"
          3. Read the task: title, description, piece_type, and attachment FILENAMES only (do NOT download attachments)
          4. Based on the classification rules below, decide the recommended model
          5. Check if task is already in progress (RESUME DETECTION):
             - Run: git branch --show-current
             - If on a feature branch that contains the task ID (e.g., "feature/9508-contact-page" for task 9508):
               → Set "resuming": true in the result
             - Otherwise: set "resuming": false

          MODEL SELECTION RULES:
          - "opus" if: Story (piece_type), Frontend work (views, CSS, JS, Slim, Tailwind, HTML templates),
            Complex backend (new models, architecture, multi-file changes, migrations),
            Ambiguous or unclear requirements, OR when in doubt
          - "sonnet" if: Simple backend (single file, minor logic change, simple CRUD, config update),
            Simple fix (CSS color change, JS tweak, typo fix, minor text change, simple validation)

          DEFAULT: "opus" (when in doubt, always choose opus)

          At the END, output JSON in this exact format - on a new line in a code block:

          ```json
          WVRUNNER_RESULT: {"status": "success", "recommended_model": "opus", "task_id": 123, "resuming": false, "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}}
          ```

          CRITICAL FORMATTING:
          1. The JSON MUST be inside triple backticks (```json ... ```) on a separate line
          2. Output VALID JSON with proper string escaping. Any quotes in string values must be escaped as \\"
          3. NO other text after the closing triple backticks
          4. recommended_model MUST be exactly "opus" or "sonnet" (lowercase, no other values)
          5. task_id MUST be the numeric relative_id of the task
          6. resuming MUST be true or false (boolean, not string)

          How to get the data:
          1. Read workvector://user -> use "hour_goal" for per_day, use "worked_out" for already_worked
             IMPORTANT: Read workvector://user at the very BEGINNING of the task before logging any work progress
          2. From the task -> extract relative_id (as task_id) and parse "duration_best" field for task_estimated
          3. Set status:
             - "success" if task analyzed successfully
             - "no_more_tasks" if no tasks available
        INSTRUCTIONS
      end
    end
  end
end
