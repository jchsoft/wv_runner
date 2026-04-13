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

      # Builds complete instructions for @next-based auto-squash runners (once/queue/today).
      # Subclasses only need to provide task_description and workflow_notice strings.
      def build_next_task_instructions(task_description:, workflow_notice:)
        project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'
        fetch_url = task_fetch_url

        <<~INSTRUCTIONS
          #{persona_instruction}

          [TASK]
          #{task_description}

          WORKFLOW:
          #{@task_id ? triaged_git_step(resuming: @resuming) : branch_resume_check_step(project_id: project_id, pull_on_main: true)}

          #{task_fetch_step(step_num: 2, fetch_url: fetch_url)}

          #{implementation_steps(start: 3)}
          #{ci_run_and_merge_step(step_num: 14, next_step: 15)}
          15. FINAL OUTPUT: Generate the result JSON

          #{workflow_notice}

          #{result_format_instruction(
            '"status": "success", "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}'
          )}

          #{hours_data_instruction}
          3. Set status:
             #{next_task_auto_squash_status_options}
        INSTRUCTIONS
      end

      def next_task_auto_squash_status_options
        <<~STATUS.strip
          - "success" if task completed and PR merged successfully
          - "no_more_tasks" if no tasks available (workvector returns "No available tasks found")
          - "ci_failed" if CI failed after retry (PR stays open)
          - "preexisting_test_errors" if tests were already failing before your changes (urgent bug task created)
          - "failure" for other errors
        STATUS
      end

      # Returns shared implementation steps from CREATE BRANCH through CODE REVIEW.
      # All four auto-squash files run these identical steps; only the starting step
      # number differs (today/once/queue start at 3, story starts at 4).
      def implementation_steps(start:)
        n = start
        [
          context_optimization_instruction,
          time_awareness_instruction,
          coding_conventions_instruction,
          preexisting_test_errors_instruction,
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
