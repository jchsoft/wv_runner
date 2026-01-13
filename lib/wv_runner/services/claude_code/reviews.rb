# frozen_string_literal: true

require_relative 'review'

module WvRunner
  module ClaudeCode
    # Handles multiple PR reviews - iterates through all PRs with reviews from project lead
    class Reviews < Review
      private

      def task_section
        <<~TASK
          [TASK]
          Find and process all Pull Requests that have unaddressed reviews from the project lead.
          Iterate through each PR, fix the review feedback, and continue until all reviews are addressed.
        TASK
      end

      def workflow_section
        <<~WORKFLOW
          WORKFLOW:
          #{find_prs_with_reviews_step}
          #{process_pr_loop_step}
          #{checkout_branch_step}
          #{load_review_comments_step}
          #{create_subtask_step}
          #{fix_review_issues_step}
          #{commit_changes_step}
          #{run_unit_tests_step}
          #{run_system_tests_step}
          #{final_commit_step}
          #{push_step}
          #{run_local_ci_step}
          #{continue_loop_step}
        WORKFLOW
      end

      def find_prs_with_reviews_step
        <<~STEP.strip
          1. FIND PRS WITH REVIEWS: Search for all open PRs with human reviews
             - Run: gh pr list --json number,title,headRefName,url --state open
             - For each PR, check if it has reviews: gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews
             - Filter for reviews from humans (not bots/automated)
             - Build a list of PRs that have unaddressed human reviews
             - If no PRs with reviews found: output success with message "no reviews to address" and STOP
        STEP
      end

      def process_pr_loop_step
        <<~STEP.strip
          2. PROCESS PR LOOP: For each PR with reviews, do the following steps (3-12)
             - Process PRs one at a time
             - After completing one PR, move to the next
        STEP
      end

      def checkout_branch_step
        <<~STEP.strip
          3. CHECKOUT BRANCH: Switch to the PR's branch
             - Run: git fetch origin {branch_name}
             - Run: git checkout {branch_name}
             - Run: git pull origin {branch_name}
        STEP
      end

      # Override to change step number
      def load_review_comments_step
        <<~STEP.strip
          4. LOAD REVIEW COMMENTS: Get the latest human review for current PR
             - Run: gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews
             - Get the most recent human review
             - Also run: gh api repos/{owner}/{repo}/pulls/{pr_number}/comments for inline comments
        STEP
      end

      # Override to change step number
      def create_subtask_step
        <<~STEP.strip
          5. CREATE SUBTASK: Extract task from PR and create subtask
             - From PR description, find WorkVector task link (workvector.com/{account}/tasks/{id})
             - Use mcp__workvector-production__CreatePieceTool to create subtask under the original task
             - Include summarized review feedback in description
             - LOG work progress to this subtask
        STEP
      end

      # Override to change step number
      def fix_review_issues_step
        <<~STEP.strip
          6. FIX REVIEW ISSUES: Address all problems mentioned in the review
             - Read the review comments carefully
             - Make necessary code changes
             - Follow Ruby/Rails best practices from global CLAUDE.md
        STEP
      end

      # Override to change step number
      def commit_changes_step
        <<~STEP.strip
          7. COMMIT CHANGES: If any changes were made
             - git add the changed files
             - git commit with clear message referencing PR review
        STEP
      end

      # Override to change step number
      def run_unit_tests_step
        <<~STEP.strip
          8. RUN UNIT TESTS: Execute all unit tests
             - Run the test suite
             - If failures: fix them and commit fixes
             - Repeat until all pass
        STEP
      end

      # Override to change step number
      def run_system_tests_step
        <<~STEP.strip
          9. RUN SYSTEM TESTS: Execute all system tests
             - Run system tests (may take up to 5 minutes)
             - If failures: fix them and commit fixes
             - Repeat until all pass
        STEP
      end

      # Override to change step number
      def final_commit_step
        <<~STEP.strip
          10. FINAL COMMIT: Commit any remaining fixes
        STEP
      end

      # Override to change step number
      def push_step
        <<~STEP.strip
          11. PUSH: Push all changes to the branch
              - git push origin HEAD
        STEP
      end

      # Override to change step number
      def run_local_ci_step
        <<~STEP.strip
          12. RUN LOCAL CI: If exists "bin/ci" file, run it
        STEP
      end

      def continue_loop_step
        <<~STEP.strip
          13. CONTINUE LOOP: Check for more PRs
              - Return to step 2 and process the next PR with reviews
              - When all PRs are processed, output final status and STOP
        STEP
      end

      def status_values_section
        <<~STATUS.strip
          Status values:
          - "success" if all reviews addressed and changes pushed
          - "no_reviews" if no PRs with human reviews found
          - "failure" for errors during processing
        STATUS
      end
    end
  end
end
