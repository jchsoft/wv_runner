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

          STEP 1 - BRANCH & RESUME DETECTION (do this FIRST):
          1. Run: git branch --show-current
          2. If on main/master: skip to STEP 2 with resuming=false
          3. If on a feature branch:
             a. Try to extract a numeric task ID (4+ digits) from the branch name
                (e.g., "feature/9508-contact-page" → task ID 9508)
             b. If NO numeric ID found in branch name, check for an open PR:
                Run: gh pr list --head $(git branch --show-current) --json body --jq '.[0].body'
                Look for a mcptask.online task link (e.g., mcptask.online/jchsoft/tasks/9508) and extract the task ID
             c. If task ID found from branch or PR: use workvector://pieces/jchsoft/{task_id} instead of the default fetch URL, set resuming=true
             d. If no task ID found at all: skip to STEP 2 with resuming=false

          STEP 2 - FETCH TASK:
          1. Fetch the task from: #{fetch_url} (unless overridden by STEP 1c)
          2. If no tasks available: output status "no_more_tasks" with recommended_model "opus"

          STEP 3 - ANALYZE:
          1. Read the task: title, description, piece_type, and attachment FILENAMES only (do NOT download attachments)
          2. Based on the classification rules below, decide the recommended model

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
