# frozen_string_literal: true

module WvRunner
  module Concerns
    # Builds instruction text blocks for Claude prompts: git steps, coding conventions, result format, time management
    module InstructionBuilding
      private

      def triaged_git_step(resuming:)
        if resuming
          <<~STEP.strip
            1. RESUME IN-PROGRESS TASK:
               - Run: git branch --show-current
               - IF already on the feature branch for this task:
                 → Pull latest main and merge: git fetch origin main && git merge origin/main
                 → Review git log and current code state to understand what was already done.
               - IF on main/master (feature branch exists elsewhere):
                 → Find the feature branch: git branch --list "*<task_id>*"
                 → Checkout it: git checkout <branch_name>
                 → Pull latest main and merge: git fetch origin main && git merge origin/main
                 → Review git log and current code state to understand what was already done.
               - SKIP steps 2-3 (task fetch, branch creation) and go directly to step 4 (IMPLEMENT).
          STEP
        else
          <<~STEP.strip
            1. GIT SETUP:
               - Run: git checkout main && git pull
               - Proceed to step 2 (TASK FETCH)
          STEP
        end
      end

      def branch_resume_check_step(project_id:, pull_on_main: true)
        pull_cmd = pull_on_main ? 'git checkout main && git pull' : 'git checkout main'
        <<~STEP.strip
          1. GIT STATE AND RESUME CHECK:
             - Run: git branch --show-current
             - IF on "main" or "master":
               → Run: #{pull_cmd}
               → Proceed to step 2 (TASK FETCH)
             - IF on ANY OTHER branch (feature branch):
               a) TRY TO IDENTIFY TASK from branch name:
                  - Branch names often contain task ID (e.g., "feature/9508-contact-page", "fix/9123-bug")
                  - Extract numeric ID from branch name
                  - If found: read workvector://pieces/jchsoft/{task_id} to load task details
               b) If no ID in branch name, check for open PR:
                  - gh pr list --head $(git branch --show-current) --json body --jq '.[0].body'
                  - Look for mcptask.online link → extract task ID → load task
               c) If STILL no task found:
                  → #{pull_cmd} → proceed to step 2
               d) CHECK TASK PROGRESS (if task was found):
                  - If progress >= 100 or state "Schváleno"/"Hotovo?":
                    → Task is done. #{pull_cmd} → proceed to step 2
                  - If progress < 100:
                    → RESUME: display WVRUNNER_TASK_INFO, SKIP steps 2-3, go to step 4
        STEP
      end

      def coding_conventions_instruction
        <<~INSTRUCTION.strip
          CODING CONVENTIONS (MANDATORY):
          - GIT COMMITS: NEVER use $() command substitution in git commit messages.
            Always pass the message as a simple quoted string directly:
            ✅ git commit -m "Fix login validation for empty emails"
            ❌ git commit -m "$(echo 'Fix login')"
            ❌ git commit -m "$(cat some_file)"
            For multi-line messages, use heredoc:
            git commit -m "$(cat <<'EOF'
            Your message here.
            EOF
            )"
          - RUBOCOP BEFORE CI: Before running bin/ci, always run RuboCop autofix on changed .rb files:
            git diff --name-only main -- '*.rb' | xargs rubocop -a
            This prevents wasting CI cycles on style violations.
        INSTRUCTION
      end

      def result_format_instruction(json_fields, extra_rules: [])
        rules = [
          'The JSON MUST be inside a ```json code block on its own line',
          '"WVRUNNER_RESULT": true MUST be the FIRST key in the JSON object',
          'Output VALID JSON - any quotes in string values must be escaped as \\"',
          *extra_rules,
          'NO other text after the closing ```'
        ]

        numbered = rules.each_with_index.map { |rule, i| "#{i + 1}. #{rule}" }.join("\n")

        <<~INSTRUCTION.strip
          At the END, output the result as valid JSON in a code block:

          ```json
          {"WVRUNNER_RESULT": true, #{json_fields}}
          ```

          CRITICAL FORMATTING:
          #{numbered}
        INSTRUCTION
      end

      def persona_instruction
        <<~INSTRUCTION.strip
          [PERSONA]
          You are a senior Ruby On Rails software developer, following RubyWay principles.
        INSTRUCTION
      end

      def task_fetch_url
        if @task_id
          "workvector://pieces/jchsoft/#{@task_id}"
        else
          project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'
          "workvector://pieces/jchsoft/@next?project_relative_id=#{project_id}"
        end
      end

      def hours_data_instruction(include_warning: false)
        warning = if include_warning
                    "\n   WARNING: \"already_worked\" is the DAILY worked hours from \"worked_out\" field " \
                      '(e.g. 3.0). Do NOT calculate it from task effort minutes or effort history!'
        else
                    ''
        end
        <<~INSTRUCTION.strip
          How to get the data:
          1. Read workvector://user -> use "hour_goal" for per_day, use "worked_out" for already_worked
             IMPORTANT: Read workvector://user at the very BEGINNING of the task before logging any work progress#{warning}
          2. From the task you're working on -> parse "duration_best" field (e.g., "1 hodina" -> 1.0) for task_estimated
        INSTRUCTION
      end

      def context_optimization_instruction
        <<~INSTRUCTION.strip
          CONTEXT OPTIMIZATION (MANDATORY):
          - ALWAYS call independent tools in parallel (multiple Read/Grep/Glob in one turn, not sequentially)
          - Use CodeGraph (`codegraph_context`, `codegraph_search`) and LSP (`findReferences`, `documentSymbol`) BEFORE Read/Grep for code exploration
          - If CodeGraph is unavailable, use LSP as PRIMARY exploration tool:
            * `documentSymbol` — file structure (classes, methods) in one call
            * `findReferences` — who calls this method/class
            * `definition` — jump to symbol definition
            * `incomingCalls` — call graph without file scanning
          - Never re-read the same file more than twice. After reading, note key line numbers — use offset+limit for targeted re-reads
          - Do NOT summarize what you just did after each step — the user sees the diff. Save output tokens.
        INSTRUCTION
      end

      def time_awareness_instruction
        <<~INSTRUCTION.strip
          TIME MANAGEMENT (CRITICAL):
          - You should aim to complete within 90 minutes, but you will only be terminated if inactive for 20 minutes.
          - "Inactive" means no new stream output for 20 minutes straight - as long as you're producing output, you're safe.
          - Before starting any long-running step (system tests, full CI), consider elapsed time.
          - If more than 70 minutes have elapsed, SKIP full test suites and full CI.
            Instead: run only targeted tests for YOUR changes, then proceed to output WVRUNNER_RESULT.
          - ALWAYS prioritize outputting WVRUNNER_RESULT when your work is complete.
        INSTRUCTION
      end
    end
  end
end
