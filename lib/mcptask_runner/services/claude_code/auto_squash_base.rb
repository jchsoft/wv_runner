# frozen_string_literal: true

require_relative '../claude_code_base'

module McptaskRunner
  module ClaudeCode
    # Base class for auto-squash workflows.
    # Provides shared instruction fragments for the implementation and CI+merge steps
    # so they are defined in one place across today/once/queue/story variants.
    class AutoSquashBase < ClaudeCodeBase
      include WorkflowSteps

      def max_turns = 300

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
          #{ci_run_and_merge_step(step_num: 13, next_step: 14)}
          14. FINAL OUTPUT: Generate the result JSON

          #{workflow_notice}

          #{result_format_instruction(
            '"status": "success", "pr_number": N, "branch_name": "...", "hours": {"per_day": X, "task_estimated": Y, "already_worked": Z}',
            extra_rules: ['pr_number + branch_name REQUIRED whenever PR was created (success / ci_failed / merge_failed / preexisting_test_errors)']
          )}

          #{auto_squash_hours_data_instruction}
          3. Set status:
             #{next_task_auto_squash_status_options}
        INSTRUCTIONS
      end

      def next_task_auto_squash_status_options
        <<~STATUS.strip
          - "success" if task completed AND `gh pr view <pr_number> --json state --jq .state` returns `MERGED`
          - "no_more_tasks" if no tasks available (mcptask returns "No available tasks found")
          - "ci_failed" if CI failed after retry (PR stays open)
          - "merge_failed" if `gh pr merge` itself errored (branch protection, conflicts, etc.)
          - "preexisting_test_errors" if tests were already failing before your changes (urgent bug task created)
          - "failure" for other errors
        STATUS
      end

      # Autosquash variant of hours_data_instruction. Same milestones but 100% is gated
      # on an actual `gh pr view` merge check — prevents marking task done when PR was
      # never merged (preexisting tests, ci_failed, merge_failed).
      def auto_squash_hours_data_instruction
        <<~INSTRUCTION.strip
          Hours data:
          1. mcptask://user (LITERAL URI — no account suffix) → "hour_goal"=per_day, "worked_out"=already_worked
             Read BEFORE logging work progress
          2. Task "duration_best" → task_estimated (e.g. "1 hodina" → 1.0)

          PROGRESS LOGGING (MANDATORY — min 3× LogWorkProgressTool calls during run):
          - Single 100% call at end = UNACCEPTABLE. Caller sees no interim state.
          - Milestones (minimum cadence, bump progress_percent each time):
            a) After branch created + task understood → ~20%
            b) After implementation + unit tests pass → ~60%
            c) ONLY after `gh pr view <pr_number> --json state --jq .state` returns `MERGED` → 100%
               UNMERGED outcomes (ci_failed / merge_failed / preexisting_test_errors / failure):
               cap at 80%. Description states non-merge reason. NEVER 100% for unmerged work.
          - Each call: duration_minutes = minutes since previous call (not cumulative);
            description = what was done since last log.
          - More calls OK for long tasks; 3× is floor, not target.
        INSTRUCTION
      end

      # Runner-side merge verification. Called from ResultParsing#parse_result via the
      # `respond_to?(:post_parse_result, true)` hook. If Claude reported `success` but
      # `gh pr view --json state` says otherwise, reclassify to `merge_unverified` so
      # the loop breaks and decider does not count the task as completed.
      def post_parse_result(result)
        return result unless result['status'] == 'success'

        pr_number = result['pr_number'] || lookup_pr_number_from_branch(result['branch_name'])
        unless pr_number
          Logger.info_stdout("[#{@log_tag}] [merge_verify] WARN: status=success but pr_number missing and lookup failed → merge_unverified")
          result['status'] = 'merge_unverified'
          result['merge_verification_error'] = 'pr_number missing and gh pr list fallback found no PR'
          return result
        end

        state_str, status = Open3.capture2('gh', 'pr', 'view', pr_number.to_s, '--json', 'state', '--jq', '.state')
        merged = status.success? && state_str.strip == 'MERGED'

        if merged
          Logger.debug "[#{@log_tag}] [merge_verify] PR ##{pr_number} confirmed merged"
          return result
        end

        reason = status.success? ? "gh pr view returned state=#{state_str.strip.inspect}" : "gh pr view exited non-zero (#{status.exitstatus})"
        Logger.info_stdout("[#{@log_tag}] [merge_verify] WARN: status=success but PR ##{pr_number} not merged (#{reason}) → merge_unverified")
        result['status'] = 'merge_unverified'
        result['merge_verification_error'] = reason
        result
      end

      def lookup_pr_number_from_branch(branch_name)
        branch = branch_name || `git branch --show-current`.strip
        return nil if branch.empty? || branch == 'main' || branch == 'master'

        out, status = Open3.capture2('gh', 'pr', 'list', '--head', branch, '--state', 'all', '--json', 'number', '--jq', '.[0].number')
        return nil unless status.success?

        n = out.strip
        n.empty? ? nil : n.to_i
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
          skip_screenshots_step(step_num: n + 9)
        ].join("\n\n")
      end

      # Returns the full CI run-and-auto-merge step.
      # step_num: the step number shown to the agent (14 for today/once/queue, 15 for story)
      # next_step: the final output step number to skip to when bin/ci is absent
      def ci_run_and_merge_step(step_num:, next_step:)
        <<~STEP
          #{step_num}. CI + AUTO-MERGE:
              - No bin/ci → skip to step #{next_step}, status "success"
              - Invoke /ci-runner
              - NOTE: bin/ci posts "signoff" status to GitHub via gh. Satisfies branch protection.
                Disabled CI workflow (ci.yml.disabled) irrelevant — signoff is local. PR IS mergeable.
              - CI PASSES:
                → gh pr merge --squash --delete-branch
                → git checkout main && git pull → status "success"
              - CI FAILS:
                → Analyze, fix, commit, push
                → Retry bin/ci
                → Retry passes → merge (above)
                → Retry fails → status "ci_failed" (PR stays open)
        STEP
      end
    end
  end
end
