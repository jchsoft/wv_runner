# frozen_string_literal: true

require_relative 'review'

module WvRunner
  module ClaudeCode
    # Handles ONE PR review - finds next PR with reviews, checks out branch, fixes issues
    # Called in a loop by WorkLoop to process multiple PRs with fresh context each time
    class Reviews < Review
      private

      def task_section
        <<~TASK
          [TASK]
          Find the NEXT Pull Request that has an unaddressed review from the project lead.
          Check out its branch, fix the review feedback, and return.
          This will be called repeatedly in a loop until no more reviews exist.
        TASK
      end

      def workflow_section
        <<~WORKFLOW
          WORKFLOW:
          #{find_next_pr_with_review_step}
          #{checkout_branch_step}
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

      def find_next_pr_with_review_step
        <<~STEP.strip
          1. FIND NEXT PR WITH REVIEW: Search for the first open PR with human reviews
             - Run: gh pr list --json number,title,headRefName,url --state open
             - For each PR, check if it has reviews: gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews
             - Filter for reviews from humans (not bots/automated)
             - Find the FIRST PR that has an unaddressed human review
             - If no PRs with reviews found: output status "no_reviews" and STOP immediately
        STEP
      end

      def checkout_branch_step
        <<~STEP.strip
          2. CHECKOUT BRANCH: Switch to the PR's branch
             - Run: git fetch origin {branch_name}
             - Run: git checkout {branch_name}
             - Run: git pull origin {branch_name}
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
          4. LOAD REVIEW COMMENTS: Get the latest human review for current PR
             - Run: gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews
             - Get the most recent human review
             - Also run: gh api repos/{owner}/{repo}/pulls/{pr_number}/comments for inline comments
        STEP
      end

      def create_subtask_step
        <<~STEP.strip
          5. CREATE SUBTASK: Create subtask for the review work
             - Use mcp__workvector-production__CreatePieceTool to create subtask under the original task
             - Include summarized review feedback in description
             - LOG work progress to this subtask
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
          12. RUN LOCAL CI: If exists "bin/ci" file, run it
        STEP
      end

      def status_values_section
        <<~STATUS.strip
          Status values:
          - "success" if review addressed and changes pushed
          - "no_reviews" if no PRs with human reviews found
          - "failure" for errors during processing
        STATUS
      end
    end
  end
end
