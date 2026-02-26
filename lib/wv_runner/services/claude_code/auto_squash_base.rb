# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Base class for auto-squash workflows.
    # Provides shared instruction fragments for the implementation and CI+merge steps
    # so they are defined in one place across today/once/queue/story variants.
    class AutoSquashBase < ClaudeCodeBase
      private

      # Returns shared implementation steps from CREATE BRANCH through "no screenshots".
      # All four auto-squash files run these identical steps; only the starting step
      # number differs (today/once/queue start at 3, story starts at 4).
      #
      # Sub-item indentation follows numbering: 3 spaces for steps 1-9, 4 for 10+.
      def implementation_steps(start:)
        n = start
        # Lambda: correct sub-item indent based on step number width
        s = ->(step) { step < 10 ? '   ' : '    ' }
        <<~STEPS
          #{n}. CREATE BRANCH: Start work on a new feature branch
          #{s.(n)}- Use task name as branch name (e.g., "feature/task-name" or "fix/issue-name")
          #{s.(n)}- Run: git checkout -b <branch-name>

          #{n+1}. IMPLEMENT TASK: Complete the task according to requirements
          #{s.(n+1)}- Follow rules in global CLAUDE.md
          #{s.(n+1)}- Make incremental commits with clear messages

          #{n+2}. RUN UNIT TESTS: Execute all unit tests
          #{s.(n+2)}- Run the test suite
          #{s.(n+2)}- If failures: fix them and commit fixes
          #{s.(n+2)}- Repeat until all pass

          #{n+3}. COMPILE TEST ASSETS: Ensure test assets are ready
          #{s.(n+3)}- Run: bin/rails assets:precompile RAILS_ENV=test
          #{s.(n+3)}- This prevents test failures due to missing compiled assets

          #{n+4}. RUN SYSTEM TESTS: Execute all system tests
          #{s.(n+4)}- Run system tests (may take up to 5 minutes)
          #{s.(n+4)}- If failures: fix them and commit fixes
          #{s.(n+4)}- Repeat until all pass

          #{n+5}. REFACTOR: Read global CLAUDE.md, then refactor with FOCUS ON ROR RULES
          #{s.(n+5)}- Apply Ruby/Rails best practices
          #{s.(n+5)}- Commit refactoring changes

          #{n+6}. VERIFY TESTS AFTER REFACTOR: Re-run all tests
          #{s.(n+6)}- Run unit tests - repeat until all pass
          #{s.(n+6)}- Run system tests - repeat until all pass

          #{n+7}. PUSH: Push branch to remote repository
          #{s.(n+7)}- Run: git push -u origin HEAD

          #{n+8}. CREATE PULL REQUEST: Open PR for CI verification
          #{s.(n+8)}- Use format from .github/pull_request_template.md if exists
          #{s.(n+8)}- Include clear summary of changes
          #{s.(n+8)}- Link to the task in WorkVector
          #{s.(n+8)}- Note: PR will be automatically merged after CI passes

          #{n+9}. do not add screenshots to PR review - it is autosquash
        STEPS
      end

      # Returns the full CI run-and-auto-merge step.
      # step_num: the step number shown to the agent (13 for today/once/queue, 14 for story)
      # next_step: the final output step number to skip to when bin/ci is absent
      def ci_run_and_merge_step(step_num:, next_step:)
        <<~STEP
          #{step_num}. RUN LOCAL CI AND AUTO-MERGE: Run CI and merge on success
              - If "bin/ci" does NOT exist: skip to step #{next_step} with status "success"
              - Run: bin/ci (NOT in background - wait for result)
              - IMPORTANT: bin/ci itself calls `gh` to post a "signoff" status check to GitHub
                when all steps pass. This is what satisfies any GitHub branch protection rule
                requiring a "signoff" check. No GitHub Actions workflow is needed for this.
                Even if a CI workflow file appears disabled (e.g. ci.yml.disabled), the branch
                protection "signoff" check is fulfilled by bin/ci running locally and posting
                the result via gh. Do NOT conclude the PR is unmergeable because of a disabled
                GitHub Actions workflow.
              - CI RESULT HANDLING:
                a) IF CI PASSES:
                   #{pr_review_check_step}
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
        STEP
      end

      # Returns the PR review check sub-step for embedding inside ci_run_and_merge_step.
      #
      # Indentation contract (tied to ci_run_and_merge_step's <<~STEP structure):
      #   - First line: no leading spaces — caller's heredoc literal provides 9 spaces
      #   - Sub-items:  11 leading spaces (9 base + 2 sub-indent)
      def pr_review_check_step
        "- CHECK PR REVIEWS: Before merging, quickly check if there are any PR review comments\n" \
        "           - Run: gh pr view --json reviews,comments\n" \
        "           - If reviews exist with actionable feedback: address relevant issues, commit, push, and re-run bin/ci\n" \
        "           - Don't overthink it - just fix obviously valid points (bugs, missing tests, style issues)\n" \
        "           - Skip irrelevant or nitpicky comments"
      end
    end
  end
end
