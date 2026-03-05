# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Processes a specific task by ID without auto-merge
    # Creates PR but leaves it open for human review
    class TaskManual < ClaudeCodeBase
      def initialize(task_id:, verbose: false, model_override: nil, resuming: false)
        super(verbose: verbose, model_override: model_override, resuming: resuming)
        @task_id = task_id
      end

      def model_name = "opusplan"

      private

      def build_instructions
        <<~INSTRUCTIONS
          [PERSONA]
          You are a senior Ruby On Rails software developer, following RubyWay principles.

          [TASK]
          Work on the specific task ##{@task_id}.

          #{time_awareness_instruction}

          #{coding_conventions_instruction}

          WORKFLOW:
          #{triaged_git_step(resuming: @resuming)}

          2. LOAD TASK: Get task details
             - Read: workvector://pieces/jchsoft/#{@task_id}
             - DISPLAY TASK INFO: After loading, output in this exact format:
               WVRUNNER_TASK_INFO:
               ID: <relative_id>
               TITLE: <task name>
               DESCRIPTION: <first 200 chars of description, or full if shorter>
               END_TASK_INFO

          3. CREATE BRANCH: Start work on a new feature branch
             - Use task name as branch name (e.g., "feature/task-name" or "fix/issue-name")
             - Run: git checkout -b <branch-name>

          4. IMPLEMENT TASK: Complete the task according to requirements
             - Follow rules in global CLAUDE.md
             - Make incremental commits with clear messages

          5. RUN UNIT TESTS: Execute all unit tests
             - Use the "test-runner" skill to run tests (invoke /test-runner)
             - If failures: fix them and commit fixes
             - Repeat until all pass

          6. PREPARE SCREENSHOTS: Save screenshots for PR review
             - If you created new system tests with visual changes, save screenshots
             - Be sure that screenshots shows tested feature, if not - scroll
             - These will be used later for PR

          7. RUN SYSTEM TESTS: Execute all system tests
             - Use the "test-runner" skill to run system tests (invoke /test-runner for system tests)
             - If failures: fix them and commit fixes
             - Repeat until all pass

          8. REFACTOR: Read global CLAUDE.md, then refactor with FOCUS ON ROR RULES
             - Apply Ruby/Rails best practices
             - Commit refactoring changes

          9. VERIFY TESTS AFTER REFACTOR: Re-run all tests
              - Use the "test-runner" skill for both unit and system tests
              - Run unit tests - repeat until all pass
              - Run system tests - repeat until all pass

          10. PUSH: Push branch to remote repository
              - Run: git push -u origin HEAD

          11. CREATE PULL REQUEST: Open PR for review (NO MERGE!)
              - Use format from .github/pull_request_template.md if exists
              - Include clear summary of changes
              - Link to the task in WorkVector
              - IMPORTANT: Do NOT merge the PR - leave it open for human review

          12. ADD SCREENSHOTS TO PR: Add screenshots using skill "pr-screenshot"
              - Make sure the test is not due to some test failure
              - Be sure that screenshots shows tested feature

          13. RUN LOCAL CI: If "bin/ci" exists, use the "ci-runner" skill
              - This step is MANDATORY - task is INCOMPLETE without CI verification
              - If bin/ci doesn't exist: skip this step
              - If some test in step 9 failed: skip this step
              - Use the "ci-runner" skill (invoke /ci-runner)

          IMPORTANT: This is a MANUAL workflow - PR is created but NOT merged!
          Human will review and merge the PR manually.

          At the END, output JSON in this exact format - on a new line in a code block:

          ```json
          WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}, "task_id": #{@task_id}}
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
             - "success" if task completed successfully (PR created, NOT merged)
             - "failure" for other errors
        INSTRUCTIONS
      end
    end
  end
end
