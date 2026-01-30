# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Processes tasks from a specific Story without auto-merge
    # Creates PRs for each task but leaves them open for human review
    class StoryManual < ClaudeCodeBase
      def initialize(story_id:, verbose: false)
        super(verbose: verbose)
        @story_id = story_id
      end

      def model_name = "opusplan"

      private

      def build_instructions
        <<~INSTRUCTIONS
          [PERSONA]
          You are a senior Ruby On Rails software developer, following RubyWay principles.

          [TASK]
          Work on the next incomplete task from Story ##{@story_id}.

          WORKFLOW:
          1. LOAD STORY: Get story details to find subtasks
             - Read: workvector://pieces/jchsoft/#{@story_id}
             - Find subtasks array in the response
             - Look for first task where state is NOT "Schváleno" and NOT "Hotovo?" and progress < 100
             - If no incomplete tasks found: STOP and output status "no_more_tasks"
             - Remember the task's relative_id for the next step

          2. LOAD TASK DETAILS: Get full task information
             - Read: workvector://pieces/jchsoft/<task_relative_id>
             - If task is IN PROGRESS (progress > 0):
               → This is a CONTINUATION - skip git checkout/branch creation (steps 3-4)
               → Go directly to step 5 (IMPLEMENT TASK) and continue where it was left off
             - If task is NEW (progress = 0): proceed normally with all steps
             - DISPLAY TASK INFO: After loading, output in this exact format:
               WVRUNNER_TASK_INFO:
               ID: <relative_id>
               TITLE: <task name>
               DESCRIPTION: <first 200 chars of description, or full if shorter>
               END_TASK_INFO

          3. GIT STATE CHECK: Ensure you start from main branch
             - Run: git checkout main && git pull
             - This ensures you start from a clean, stable state

          4. CREATE BRANCH: Start work on a new feature branch
             - Use task name as branch name (e.g., "feature/task-name" or "fix/issue-name")
             - Run: git checkout -b <branch-name>

          5. IMPLEMENT TASK: Complete the task according to requirements
             - Follow rules in global CLAUDE.md
             - Make incremental commits with clear messages

          6. RUN UNIT TESTS: Execute all unit tests
             - Run the test suite
             - If failures: fix them and commit fixes
             - Repeat until all pass

          7. PREPARE SCREENSHOTS: Save screenshots for PR review
             - If you created new system tests with visual changes, save screenshots
             - Be sure that screenshots shows tested feature, if not - scroll
             - These will be used later for PR

          8. RUN SYSTEM TESTS: Execute all system tests
             - Run system tests (may take up to 5 minutes)
             - If failures: fix them and commit fixes
             - Repeat until all pass

          9. REFACTOR: Read global CLAUDE.md, then refactor with FOCUS ON ROR RULES
             - Apply Ruby/Rails best practices
             - Commit refactoring changes

          10. VERIFY TESTS AFTER REFACTOR: Re-run all tests
              - Run unit tests - repeat until all pass
              - Run system tests - repeat until all pass

          11. PUSH: Push branch to remote repository
              - Run: git push -u origin HEAD

          12. CREATE PULL REQUEST: Open PR for review (NO MERGE!)
              - Use format from .github/pull_request_template.md if exists
              - Include clear summary of changes
              - Link to the task in WorkVector
              - IMPORTANT: Do NOT merge the PR - leave it open for human review

          13. ADD SCREENSHOTS TO PR: Add screenshots using skill "pr-screenshot"
              - Make sure the test is not due to some test failure
              - Be sure that screenshots shows tested feature

          14. RUN LOCAL CI: If "bin/ci" exists, run it in background to avoid timeout
              - This step is MANDATORY - task is INCOMPLETE without CI verification
              - If bin/ci doesn't exist: skip this step
              - If some test in step 10. failed: skip this step
              - IMPORTANT: Use Bash tool with run_in_background=true to start CI
              - Then poll the output every 5 minutes using Read or Bash tail until complete
              - This prevents API timeout during long-running CI

          IMPORTANT: This is a MANUAL workflow - PR is created but NOT merged!
          Human will review and merge the PR manually.

          At the END, output JSON in this exact format - on a new line in a code block:

          ```json
          WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": X, "task_estimated": Y}, "story_id": #{@story_id}, "task_id": Z}
          ```

          CRITICAL FORMATTING:
          1. The JSON MUST be inside triple backticks (```json ... ```) on a separate line
          2. Output VALID JSON with proper string escaping. Any quotes in string values must be escaped as \\"
          3. NO other text after the closing triple backticks

          How to get the data:
          1. Read workvector://user -> use "hour_goal" value for per_day
          2. From the task you're working on -> parse "duration_best" field (e.g., "1 hodina" -> 1.0) for task_estimated
          3. task_id: relative_id of the task you worked on
          4. Set status:
             - "success" if task completed successfully (PR created, NOT merged)
             - "no_more_tasks" if no incomplete tasks in the Story
             - "failure" for other errors
        INSTRUCTIONS
      end
    end
  end
end
