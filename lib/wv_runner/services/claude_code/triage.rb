# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Triage step - cheap Haiku call that analyzes task complexity
    # and recommends the optimal model for execution
    class Triage < ClaudeCodeBase
      def initialize(verbose: false, task_id: nil, story_id: nil)
        super(verbose: verbose)
        @task_id = task_id
        @story_id = story_id
      end

      def model_name = "haiku"

      private

      def accept_edits?
        false
      end

      def build_instructions
        @story_id ? build_story_triage_instructions : build_standard_triage_instructions
      end

      def build_story_triage_instructions
        <<~INSTRUCTIONS
          You are a task triage agent. Your ONLY job is to find the next incomplete subtask from a Story and recommend which AI model should execute it.
          OUTPUT ONLY the final JSON result block. No explanations, no analysis, no commentary before or after the JSON.

          #{daily_quota_check_step}

          STEP 1 - LOAD STORY:
          1. Read: workvector://pieces/jchsoft/#{@story_id}
          2. Find subtasks array in the response
          3. Look for first task where state is NOT "Schváleno" and NOT "Hotovo?" and progress < 100
          4. If no incomplete tasks found: output status "no_more_tasks" with recommended_model "opus"
          5. Remember the task's relative_id for the next step

          STEP 2 - FETCH TASK:
          1. Read: workvector://pieces/jchsoft/<task_relative_id> (the task found in STEP 1)

          STEP 3 - ANALYZE:
          1. Read the task: title, description, piece_type, and attachment FILENAMES only (do NOT download attachments)
          2. Based on the classification rules below, decide the recommended model

          #{model_selection_rules}

          #{result_format_instruction(
            '"status": "success", "recommended_model": "sonnet", "task_id": 123, "resuming": false, "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}',
            extra_rules: [
              'recommended_model MUST be exactly "opus", "sonnet", or "haiku" (lowercase)',
              'task_id MUST be the numeric relative_id of the subtask (NOT the story)',
              'resuming MUST be false (story triage always starts fresh tasks)',
              'already_worked MUST be the EXACT "worked_out" number from workvector://user - NEVER 0 unless API returned 0'
            ]
          )}

          #{triage_hours_instruction(entity: 'subtask', status_entries: story_triage_status_entries)}
        INSTRUCTIONS
      end

      def build_standard_triage_instructions
        fetch_url = task_fetch_url

        <<~INSTRUCTIONS
          You are a task triage agent. Your ONLY job is to analyze a task and recommend which AI model should execute it.
          OUTPUT ONLY the final JSON result block. No explanations, no analysis, no commentary before or after the JSON.

          #{daily_quota_check_step}

          #{branch_detection_step}

          STEP 2 - FETCH TASK:
          1. Fetch the task from: #{fetch_url}#{" (unless overridden by STEP 1c)" unless @task_id}
          2. If no tasks available: output status "no_more_tasks" with recommended_model "opus"
          3. Check the "type" field of the fetched piece:
             - If type is "Story": go to STEP 2b (Story handling)
             - If type is "Task": go to STEP 3 (Analyze)

          STEP 2b - STORY HANDLING (only if type is "Story"):
          1. Remember the Story's relative_id as story_id
          2. Find subtasks array in the response
          3. Look for first task where state is NOT "Schváleno" and NOT "Hotovo?" and progress < 100
          4. If no incomplete subtasks found: output status "no_more_tasks" with recommended_model "opus", piece_type "Story"
          5. Fetch the subtask: Read workvector://pieces/jchsoft/<subtask_relative_id>
          6. Continue to STEP 3 with the SUBTASK data (not the Story)
          7. IMPORTANT: In the final result, set piece_type to "Story" and story_id to the Story's relative_id, and task_id to the subtask's relative_id

          STEP 3 - ANALYZE:
          1. Read the task: title, description, piece_type, and attachment FILENAMES only (do NOT download attachments)
          2. Based on the classification rules below, decide the recommended model

          #{model_selection_rules}

          #{result_format_instruction(
            '"status": "success", "recommended_model": "sonnet", "task_id": 123, "resuming": false, "piece_type": "Task", "story_id": null, "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}',
            extra_rules: [
              'recommended_model MUST be exactly "opus", "sonnet", or "haiku" (lowercase)',
              'task_id MUST be the numeric relative_id of the task (or subtask if Story was detected)',
              'resuming MUST be true or false (boolean, not string)',
              'piece_type MUST be "Task" or "Story" — set to "Story" ONLY if the fetched piece was a Story (STEP 2b)',
              'story_id MUST be the numeric relative_id of the Story if piece_type is "Story", otherwise null',
              'already_worked MUST be the EXACT "worked_out" number from workvector://user - NEVER 0 unless API returned 0'
            ]
          )}

          #{triage_hours_instruction(entity: 'task', status_entries: standard_triage_status_entries)}
        INSTRUCTIONS
      end

      def story_triage_status_entries
        "- \"success\" if subtask analyzed successfully\n" \
          "- \"no_more_tasks\" if no incomplete subtasks in the Story\n" \
          '- "quota_exceeded" if worked_out >= hour_goal (from STEP 0)'
      end

      def standard_triage_status_entries
        "- \"success\" if task analyzed successfully\n" \
          "- \"no_more_tasks\" if no tasks available\n" \
          '- "quota_exceeded" if worked_out >= hour_goal (from STEP 0)'
      end

      def daily_quota_check_step
        <<~STEP.strip
          STEP 0 - CHECK DAILY QUOTA (do this FIRST, before anything else):
          1. Read: workvector://user
          2. Extract "hour_goal" (this is per_day) and "worked_out" (this is already_worked)
          3. CRITICAL: If worked_out >= hour_goal → STOP IMMEDIATELY. Output WVRUNNER_RESULT with:
             - status: "quota_exceeded", recommended_model: "opus", task_id: 0, resuming: false
             - hours: { per_day: <hour_goal value>, task_estimated: 0, already_worked: <worked_out value> }
             Do NOT proceed to any other steps. Do NOT fetch any task.
          4. If worked_out < hour_goal → continue to STEP 1
        STEP
      end

      def model_selection_rules
        <<~RULES.strip
          MODEL SELECTION RULES (pick exactly one: "opus", "sonnet", or "haiku"):

          Use "haiku" for trivial changes:
          - Typo fix, text correction, translation string change
          - Single CSS property change (color, font-size, margin)
          - One-line config update (env variable, locale key, feature flag)

          Use "opus" ONLY for:
          - New UI elements, UI improvements, UI beautification (new pages, design changes, UX enhancements)
          - Complex architecture (new models with associations, multi-service orchestration, migrations with data transforms)
          - Security-sensitive changes (authentication, authorization, encryption)
          - Ambiguous or unclear requirements needing creative interpretation
          - Story (piece_type)

          Use "sonnet" for everything else, including:
          - Standard CRUD (even multi-file: model + controller + views for simple resources)
          - Refactoring (extract method, rename, move code, extract concern)
          - Bug fixes with clear error messages or stack traces
          - Adding/modifying tests
          - Simple frontend changes (fix existing CSS, tweak existing JS, adjust existing layout)
          - Validations, scopes, simple associations, callbacks
          - Config, environment, locale, or documentation changes
          - API endpoints with straightforward logic

          DURATION HINT: tasks estimated under 1 hour (duration_best) lean toward "sonnet" or "haiku"

          DEFAULT: "sonnet" (when in doubt, choose sonnet — it handles most standard dev work well)
        RULES
      end

      def triage_hours_instruction(entity:, status_entries:)
        <<~INSTRUCTION.strip
          How to populate hours in the result:
          1. per_day = "hour_goal" from workvector://user (already read in STEP 0)
          2. already_worked = "worked_out" from workvector://user (already read in STEP 0)
          3. task_estimated = parse "duration_best" field from #{entity} (e.g. "30 minut" → 0.5, "1 hodina" → 1.0)
          4. Set status:
             #{status_entries}
        INSTRUCTION
      end

      def branch_detection_step
        if @task_id
          <<~STEP.strip
            STEP 1 - BRANCH & RESUME DETECTION (do this FIRST):
            1. Run: git branch --show-current
            2. If on a feature branch that contains "#{@task_id}" in its name: set resuming=true
            3. If on main/master:
               a. Check for existing feature branch: git branch --list "*#{@task_id}*"
               b. If a matching branch exists: set resuming=true (the branch will be checked out in the executor)
               c. If no matching branch: set resuming=false
            4. Otherwise (different feature branch): set resuming=false
            NOTE: The task to analyze is ALREADY determined (#{@task_id}). Do NOT fetch a different task.
          STEP
        else
          <<~STEP.strip
            STEP 1 - BRANCH & RESUME DETECTION (do this FIRST):
            1. Run: git branch --show-current
            2. If on main/master:
               a. Skip to STEP 2 with resuming=false
            3. If on a feature branch:
               a. Try to extract a numeric task ID (4+ digits) from the branch name
                  (e.g., "feature/9508-contact-page" → task ID 9508)
               b. If NO numeric ID found in branch name, check for an open PR:
                  Run: gh pr list --head $(git branch --show-current) --json body --jq '.[0].body'
                  Look for a mcptask.online task link (e.g., mcptask.online/jchsoft/tasks/9508) and extract the task ID
               c. If task ID found from branch or PR: use workvector://pieces/jchsoft/{task_id} instead of the default fetch URL, set resuming=true
               d. If no task ID found at all: skip to STEP 2 with resuming=false
          STEP
        end
      end
    end
  end
end
