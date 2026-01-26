# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Handles PR review feedback - reads human reviews, creates subtasks, fixes issues
    class Review < ClaudeCodeBase
      def model_name = "sonnet"

      private

      def build_instructions
        [
          persona_section,
          task_section,
          workflow_section,
          output_format_section
        ].join("\n")
      end

      def persona_section
        <<~PERSONA
          [PERSONA]
          You are a senior Ruby On Rails software developer, following RubyWay principles.
        PERSONA
      end

      def task_section
        <<~TASK
          [TASK]
          Review and fix feedback from Pull Request reviews on the current branch.
        TASK
      end

      def workflow_section
        <<~WORKFLOW
          WORKFLOW:
          #{git_state_check_step}
          #{pr_existence_check_step}
          #{extract_task_info_step}
          #{load_review_comments_step}
          #{create_subtask_step}
          #{fix_review_issues_step}
          #{commit_changes_step}
          #{run_unit_tests_step}
          #{run_system_tests_step}
          #{final_commit_step}
          #{push_step}
          #{run_local_ci_step}
        WORKFLOW
      end

      def git_state_check_step
        <<~STEP.strip
          1. GIT STATE CHECK: Verify you are NOT on main/master branch
             - Run: git branch --show-current
             - If on main or master: STOP and output error status - cannot review on main branch
             - If on feature branch: continue
        STEP
      end

      def pr_existence_check_step
        <<~STEP.strip
          2. PR EXISTENCE CHECK: Verify a PR exists for current branch
             - Run: gh pr view --json number,title,body,url
             - If no PR exists: STOP and output error status - no PR found for this branch
        STEP
      end

      def extract_task_info_step
        <<~STEP.strip
          3. EXTRACT TASK INFO: From PR description, find the WorkVector task link
             - Look for URL pattern: workvector.com/{account}/tasks/{id}
             - Extract account code and task ID
        STEP
      end

      def load_review_comments_step
        <<~STEP.strip
          4. LOAD REVIEW COMMENTS: Get the latest human review
             - Run: gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews
             - Filter for reviews from humans (not bots/automated)
             - Get the most recent human review
             - Also run: gh api repos/{owner}/{repo}/pulls/{pr_number}/comments for inline comments
             - If no human reviews found: output success with message "no reviews to address"
        STEP
      end

      def create_subtask_step
        <<~STEP.strip
          5. CREATE SUBTASK
             - Use mcp__workvector-production__CreatePieceTool to create subtask under the original task
             - Include summarized review feedback in description
             - LOG work progress to this task
        STEP
      end

      def fix_review_issues_step
        <<~STEP.strip
          6. FIX REVIEW ISSUES: Address all problems mentioned in the review
             - Read the review comments carefully
             - Make necessary code changes
             - Follow Ruby/Rails best practices from global CLAUDE.md
        STEP
      end

      def commit_changes_step
        <<~STEP.strip
          7. COMMIT CHANGES: If any changes were made
             - git add the changed files
             - git commit with clear message referencing PR review
        STEP
      end

      def run_unit_tests_step
        <<~STEP.strip
          8. RUN UNIT TESTS: Execute all unit tests
             - Run the test suite
             - If failures: fix them and commit fixes
             - Repeat until all pass
        STEP
      end

      def run_system_tests_step
        <<~STEP.strip
          9. RUN SYSTEM TESTS: Execute all system tests
             - Run system tests (may take up to 5 minutes)
             - If failures: fix them and commit fixes
             - Repeat until all pass
        STEP
      end

      def final_commit_step
        <<~STEP.strip
          10. FINAL COMMIT: Commit any remaining fixes
        STEP
      end

      def push_step
        <<~STEP.strip
          11. PUSH: Push all changes to the branch
              - git push origin HEAD
        STEP
      end

      def run_local_ci_step
        <<~STEP.strip
          12. RUN LOCAL CI: If "bin/ci" exists, run it in background to avoid timeout
              - IMPORTANT: Use Bash tool with run_in_background=true to start CI
              - Then poll the output every 30 seconds using Read or Bash tail until complete
              - This prevents API timeout during long-running CI
        STEP
      end

      def output_format_section
        <<~OUTPUT
          At the END, output JSON in this exact format - on a new line in a code block:

          ```json
          WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": X, "task_estimated": Y}}
          ```

          CRITICAL FORMATTING:
          1. The JSON MUST be inside triple backticks (```json ... ```) on a separate line
          2. Output VALID JSON with proper string escaping. Any quotes in string values must be escaped as \\"
          3. NO other text after the closing triple backticks

          #{status_values_section}
          #{hours_data_section}
        OUTPUT
      end

      def status_values_section
        <<~STATUS.strip
          Status values:
          - "success" if review addressed and changes pushed
          - "no_reviews" if no human reviews found to address
          - "not_on_branch" if on main/master branch
          - "no_pr" if no PR exists for current branch
          - "failure" for other errors
        STATUS
      end

      def hours_data_section
        <<~HOURS.strip
          How to get hours data:
          1. Read workvector://user -> use "hour_goal" value for per_day
          2. Set task_estimated to 0.5 (review tasks are typically short)
        HOURS
      end
    end
  end
end
