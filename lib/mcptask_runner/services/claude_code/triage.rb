# frozen_string_literal: true

require_relative '../claude_code_base'

module McptaskRunner
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
          Task triage agent. Find next incomplete subtask from Story, recommend model.
          OUTPUT ONLY JSON. No explanations, no commentary.

          #{daily_quota_check_step}

          STEP 1 - LOAD STORY:
          1. Read mcptask://pieces/jchsoft/#{@story_id}
          2. Find subtasks
          3. First task: NOT "Schváleno"/"Hotovo?", progress<100
          4. None found → status "no_more_tasks", recommended_model="opus"
          5. Remember task relative_id

          STEP 2 - FETCH TASK: Read mcptask://pieces/jchsoft/<task_relative_id>

          STEP 3 - ANALYZE: Read title, description, piece_type, attachment filenames (no downloads). Apply model rules below.

          #{model_selection_rules}

          #{result_format_instruction(
            '"status": "success", "recommended_model": "sonnet", "task_id": 123, "resuming": false, "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}',
            extra_rules: [
              'recommended_model: "opus"/"sonnet"/"haiku" (lowercase)',
              'task_id = subtask relative_id (NOT story)',
              'resuming = false (story triage = fresh tasks)',
              'already_worked = exact "worked_out" from mcptask://user — never 0 unless API returned 0'
            ]
          )}

          #{triage_hours_instruction(entity: 'subtask', status_entries: story_triage_status_entries)}
        INSTRUCTIONS
      end

      def build_standard_triage_instructions
        fetch_url = task_fetch_url

        <<~INSTRUCTIONS
          Task triage agent. Analyze task, recommend model.
          OUTPUT ONLY JSON. No explanations, no commentary.

          #{daily_quota_check_step}

          #{branch_detection_step}

          STEP 2 - FETCH: #{fetch_url}#{" (unless STEP 1c override)" unless @task_id}
          - No tasks → status "no_more_tasks", recommended_model="opus"
          - type="Story" → STEP 2b
          - type="Task" → STEP 3

          STEP 2b - STORY:
          1. story_id = Story's relative_id
          2. First subtask: NOT "Schváleno"/"Hotovo?", progress<100
          3. None → status "no_more_tasks", recommended_model="opus", piece_type="Story"
          4. Fetch mcptask://pieces/jchsoft/<subtask_id>
          5. STEP 3 with SUBTASK data
          6. Result: piece_type="Story", story_id=Story's relative_id, task_id=subtask's relative_id

          STEP 3 - ANALYZE: Read title, description, piece_type, attachment filenames (no downloads). Apply model rules below.

          #{model_selection_rules}

          #{result_format_instruction(
            '"status": "success", "recommended_model": "sonnet", "task_id": 123, "resuming": false, "piece_type": "Task", "story_id": null, "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}',
            extra_rules: [
              'recommended_model: "opus"/"sonnet"/"haiku" (lowercase)',
              'task_id = relative_id of task (or subtask if Story)',
              'resuming: boolean (not string)',
              'piece_type: "Task" or "Story" (Story only if STEP 2b)',
              'story_id: Story relative_id if piece_type="Story", else null',
              'already_worked = exact "worked_out" — never 0 unless API returned 0'
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
          STEP 0 - DAILY QUOTA (FIRST):
          1. Read mcptask://user (LITERAL URI — no account suffix, no path after /user). Extract "hour_goal" + "worked_out".
             MANDATORY: per_day MUST be a number from hour_goal. Never null. If endpoint fails, retry — do NOT proceed.
          2. worked_out >= hour_goal → STOP. TASKRUNNER_RESULT:
             status="quota_exceeded", recommended_model="opus", task_id=0, resuming=false
             hours: {per_day: <hour_goal>, task_estimated: 0, already_worked: <worked_out>}
          3. worked_out < hour_goal → STEP 1
        STEP
      end

      def model_selection_rules
        <<~RULES.strip
          MODEL SELECTION (pick one: "opus"/"sonnet"/"haiku"):

          "haiku": trivial — typo fix, single CSS change, one-line config

          "opus" ONLY: UI elements/improvements/beautification, complex architecture (models+associations, multi-service, migrations w/ data transforms), security (auth/encryption), ambiguous requirements, Story type

          "sonnet" (DEFAULT): everything else — CRUD, refactoring, bug fixes, tests, simple frontend, validations/scopes/callbacks, config/locale/docs, API endpoints

          DURATION HINT: <1 hour → lean sonnet/haiku
        RULES
      end

      def triage_hours_instruction(entity:, status_entries:)
        <<~INSTRUCTION.strip
          Hours:
          1. per_day = "hour_goal" (from STEP 0)
          2. already_worked = "worked_out" (from STEP 0)
          3. task_estimated = "duration_best" from #{entity} (e.g. "30 minut"→0.5, "1 hodina"→1.0)
          4. Status:
             #{status_entries}
        INSTRUCTION
      end

      def branch_detection_step
        if @task_id
          <<~STEP.strip
            STEP 1 - RESUME DETECTION:
            1. git branch --show-current
            2. Feature branch contains "#{@task_id}" → resuming=true
            3. On main/master:
               a. git branch --list "*#{@task_id}*"
               b. Match found → resuming=true
               c. No match → resuming=false
            4. Other branch → resuming=false
            Task already set: #{@task_id}. Do NOT fetch different task.
          STEP
        else
          <<~STEP.strip
            STEP 1 - RESUME DETECTION:
            1. git branch --show-current
            2. main/master → STEP 2, resuming=false
            3. Feature branch:
               a. Extract 4+ digit task ID from branch (e.g. "feature/9508-..." → 9508)
               b. No ID → check PR: gh pr list --head $(git branch --show-current) --json body --jq '.[0].body'
                  Look for mcptask.online link → extract task ID
               c. Found → mcptask://pieces/jchsoft/{task_id}, resuming=true
               d. Not found → STEP 2, resuming=false
          STEP
        end
      end
    end
  end
end
