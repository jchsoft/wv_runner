# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Executes real work - creates branches, modifies code, creates PRs
    class Honest < ClaudeCodeBase
      def model_name
        'opus'
      end

      private

      def build_instructions
        project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'

        <<~INSTRUCTIONS
          [PERSONA]
          You are a senior Ruby On Rails software developer, following RubyWay principles.
          [TASK]
          Work on next task from: workvector://pieces/jchsoft/@next?project_relative_id=#{project_id} and ultrathink!

          WORKFLOW:
          1. GIT STATE CHECK: Ensure you start from main branch
             - Run: git checkout main
             - This ensures you start from a clean, stable state

          2. TASK FETCH: Get the next available task
             - Read: workvector://pieces/jchsoft/@next?project_relative_id=#{project_id}
             - If no tasks available: STOP and output status "no_more_tasks"
             - Verify task is NOT already started or completed

          3. CREATE BRANCH: Start work on a new feature branch
             - Use task name as branch name (e.g., "feature/task-name" or "fix/issue-name")
             - Run: git checkout -b <branch-name>

          4. IMPLEMENT TASK: Complete the task according to requirements
             - Follow rules in global CLAUDE.md
             - Make incremental commits with clear messages

          5. RUN UNIT TESTS: Execute all unit tests
             - Run the test suite
             - If failures: fix them and commit fixes
             - Repeat until all pass

          6. PREPARE SCREENSHOTS: Save screenshots for PR review
             - If you created new system tests with visual changes, save screenshots
             - These will be used later for PR

          7. RUN SYSTEM TESTS: Execute all system tests
             - Run system tests (may take up to 5 minutes)
             - If failures: fix them and commit fixes
             - Repeat until all pass

          8. REFACTOR: Read global CLAUDE.md, then refactor with FOCUS ON ROR RULES
             - Apply Ruby/Rails best practices
             - Commit refactoring changes

          9. VERIFY TESTS AFTER REFACTOR: Re-run all tests
             - Run unit tests - repeat until all pass
             - Run system tests - repeat until all pass

          10. PUSH: Push branch to remote repository
              - Run: git push origin HEAD

          11. CREATE PULL REQUEST: Open PR for review
              - Use format from .github/pull_request_template.md if exists
              - Include clear summary of changes
              - Link to the task in WorkVector

          12. ADD SCREENSHOTS TO PR: Add screenshots using skill "pr-screenshot"

          13. RUN LOCAL CI: If "bin/ci" exists, run it to verify PR passes
              - This step is MANDATORY - task is INCOMPLETE without CI verification
              - If bin/ci doesn't exist: skip this step

          ⚠️ TASK IS NOT COMPLETE UNTIL LOCAL CI PASSES (step 13)

          At the END, output JSON in this exact format - on a new line in a code block:

          ```json
          WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": X, "task_estimated": Y}}
          ```

          CRITICAL FORMATTING:
          1. The JSON MUST be inside triple backticks (```json ... ```) on a separate line
          2. Output VALID JSON with proper string escaping. Any quotes in string values must be escaped as \\"
          3. NO other text after the closing triple backticks

          How to get the data:
          1. Read workvector://user -> use "hour_goal" value for per_day
          2. From the task you're working on -> parse "duration_best" field (e.g., "1 hodina" -> 1.0) for task_estimated
          3. Set status:
             - "success" if task completed successfully
             - "no_more_tasks" if no tasks available (workvector returns "No available tasks found")
             - "failure" for other errors
        INSTRUCTIONS
      end
    end
  end
end
