# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Handles PR review feedback - reads human reviews, creates subtasks, fixes issues
    class Review < ClaudeCodeBase
      def model_name
        'sonnet'
      end

      private

      def build_instructions
        <<~INSTRUCTIONS
          [PERSONA]
          You are a senior Ruby On Rails software developer, following RubyWay principles.
          [TASK]
          Review and fix feedback from Pull Request reviews on the current branch.

          WORKFLOW:
          1. GIT STATE CHECK: Verify you are NOT on main/master branch
             - Run: git branch --show-current
             - If on main or master: STOP and output error status - cannot review on main branch
             - If on feature branch: continue

          2. PR EXISTENCE CHECK: Verify a PR exists for current branch
             - Run: gh pr view --json number,title,body,url
             - If no PR exists: STOP and output error status - no PR found for this branch

          3. EXTRACT TASK INFO: From PR description, find the WorkVector task link
             - Look for URL pattern: workvector.com/{account}/tasks/{id}
             - Extract account code and task ID

          4. LOAD REVIEW COMMENTS: Get the latest human review
             - Run: gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews
             - Filter for reviews from humans (not bots/automated)
             - Get the most recent human review
             - Also run: gh api repos/{owner}/{repo}/pulls/{pr_number}/comments for inline comments
             - If no human reviews found: output success with message "no reviews to address"

          5. CREATE SUBTASK (optional): If review has substantial feedback
             - Use mcp__workvector-production__CreatePieceTool to create subtask under the original task
             - Include summarized review feedback in description

          6. FIX REVIEW ISSUES: Address all problems mentioned in the review
             - Read the review comments carefully
             - Make necessary code changes
             - Follow Ruby/Rails best practices from global CLAUDE.md

          7. COMMIT CHANGES: If any changes were made
             - git add the changed files
             - git commit with clear message referencing PR review

          8. RUN UNIT TESTS: Execute all unit tests
             - Run the test suite
             - If failures: fix them and commit fixes
             - Repeat until all pass

          9. RUN SYSTEM TESTS: Execute all system tests
             - Run system tests (may take up to 5 minutes)
             - If failures: fix them and commit fixes
             - Repeat until all pass

          10. FINAL COMMIT: Commit any remaining fixes

          11. PUSH: Push all changes to the branch
              - git push origin HEAD

          At the END, output JSON in this exact format - on a new line in a code block:

          ```json
          WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": X, "task_estimated": Y}}
          ```

          CRITICAL FORMATTING:
          1. The JSON MUST be inside triple backticks (```json ... ```) on a separate line
          2. Output VALID JSON with proper string escaping. Any quotes in string values must be escaped as \\"
          3. NO other text after the closing triple backticks

          Status values:
          - "success" if review addressed and changes pushed
          - "no_reviews" if no human reviews found to address
          - "not_on_branch" if on main/master branch
          - "no_pr" if no PR exists for current branch
          - "failure" for other errors

          How to get hours data:
          1. Read workvector://user -> use "hour_goal" value for per_day
          2. Set task_estimated to 0.5 (review tasks are typically short)
        INSTRUCTIONS
      end
    end
  end
end
