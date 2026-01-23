# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Processes tasks from @next queue with automatic PR squash-merge after CI passes
    # Similar to run_today but with automatic merge instead of leaving PR open
    class TodayAutoSquash < ClaudeCodeBase
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
          Work on the next available task with AUTOMATIC PR merge after CI passes.

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
             - Be sure that screenshots shows tested feature, if not - scroll
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
              - Run: git push -u origin HEAD

          11. CREATE PULL REQUEST: Open PR for CI verification
              - Use format from .github/pull_request_template.md if exists
              - Include clear summary of changes
              - Link to the task in WorkVector
              - Note: PR will be automatically merged after CI passes

          12. ADD SCREENSHOTS TO PR: Add screenshots using skill "pr-screenshot"
              - Make sure the test is not due to some test failure
              - Be sure that screenshots shows tested feature

          13. RUN LOCAL CI AND AUTO-MERGE: Run CI and merge on success
              - If "bin/ci" does NOT exist: skip to step 14 with status "success"
              - Run: bin/ci (NOT in background - wait for result)
              - CI RESULT HANDLING:
                a) IF CI PASSES:
                   - Run: gh pr merge --squash --delete-branch
                   - Run: git checkout main && git pull
                   - Output status "success"
                b) IF CI FAILS (first attempt):
                   - Analyze the failure output
                   - Fix the issues
                   - Commit and push fixes
                   - Retry CI: bin/ci
                   - IF RETRY PASSES: merge as in (a)
                   - IF RETRY FAILS: output status "ci_failed" (PR stays open)

          14. FINAL OUTPUT: Generate the result JSON

          IMPORTANT: This is an AUTO-SQUASH workflow - PR is automatically merged after CI passes!
          If CI fails twice, the PR stays open for manual review.

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
             - "success" if task completed and PR merged successfully
             - "no_more_tasks" if no tasks available (workvector returns "No available tasks found")
             - "ci_failed" if CI failed after retry (PR stays open)
             - "failure" for other errors
        INSTRUCTIONS
      end
    end
  end
end
