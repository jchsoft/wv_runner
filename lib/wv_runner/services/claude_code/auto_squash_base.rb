# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Base class for auto-squash workflows.
    # Provides shared instruction fragments for the implementation and CI+merge steps
    # so they are defined in one place across today/once/queue/story variants.
    class AutoSquashBase < ClaudeCodeBase
      include WorkflowSteps

      private

      # Returns shared implementation steps from CREATE BRANCH through CODE REVIEW.
      # All four auto-squash files run these identical steps; only the starting step
      # number differs (today/once/queue start at 3, story starts at 4).
      def implementation_steps(start:)
        n = start
        [
          time_awareness_instruction,
          coding_conventions_instruction,
          create_branch_step(step_num: n),
          implement_task_step(step_num: n + 1),
          run_unit_tests_step(step_num: n + 2),
          compile_test_assets_step(step_num: n + 3),
          run_system_tests_step(step_num: n + 4),
          refactor_step(step_num: n + 5),
          verify_tests_step(step_num: n + 6),
          push_step(step_num: n + 7),
          create_pr_step(step_num: n + 8, auto_merge_note: true),
          skip_screenshots_step(step_num: n + 9),
          code_review_step(step_num: n + 10)
        ].join("\n\n")
      end

      # Returns the full CI run-and-auto-merge step.
      # step_num: the step number shown to the agent (14 for today/once/queue, 15 for story)
      # next_step: the final output step number to skip to when bin/ci is absent
      def ci_run_and_merge_step(step_num:, next_step:)
        <<~STEP
          #{step_num}. RUN LOCAL CI AND AUTO-MERGE: Run CI and merge on success
              - If "bin/ci" does NOT exist: skip to step #{next_step} with status "success"
              - Use the "ci-runner" skill to run bin/ci (invoke /ci-runner)
              - IMPORTANT: bin/ci itself calls `gh` to post a "signoff" status check to GitHub
                when all steps pass. This is what satisfies any GitHub branch protection rule
                requiring a "signoff" check. No GitHub Actions workflow is needed for this.
                Even if a CI workflow file appears disabled (e.g. ci.yml.disabled), the branch
                protection "signoff" check is fulfilled by bin/ci running locally and posting
                the result via gh. Do NOT conclude the PR is unmergeable because of a disabled
                GitHub Actions workflow.
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
        STEP
      end
    end
  end
end
