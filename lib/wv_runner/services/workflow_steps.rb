# frozen_string_literal: true

module WvRunner
  # Shared workflow step definitions for implementation workflows.
  # Included by AutoSquashBase and manual workflow classes (Honest, TaskManual, StoryManual).
  # Each method returns a formatted step string ready for embedding in instructions.
  module WorkflowSteps
    private

    # Sub-item indentation: 3 spaces for steps 1-9, 4 for 10+
    def step_indent(step_num)
      step_num < 10 ? '   ' : '    '
    end

    def task_fetch_step(step_num:, fetch_url:)
      s = step_indent(step_num)
      <<~STEP.strip
        #{step_num}. TASK FETCH: Get the next available task
        #{s}- Read: #{fetch_url}
        #{s}- If no tasks available: STOP and output status "no_more_tasks"
        #{s}- Verify task is NOT already started or completed
        #{s}- DISPLAY TASK INFO: After loading, output in this exact format:
        #{s}  WVRUNNER_TASK_INFO:
        #{s}  ID: <relative_id>
        #{s}  TITLE: <task name>
        #{s}  DESCRIPTION: <first 200 chars of description, or full if shorter>
        #{s}  END_TASK_INFO
      STEP
    end

    def load_task_step(step_num:, task_id:)
      s = step_indent(step_num)
      <<~STEP.strip
        #{step_num}. LOAD TASK: Get task details
        #{s}- Read: workvector://pieces/jchsoft/#{task_id}
        #{s}- DISPLAY TASK INFO: After loading, output in this exact format:
        #{s}  WVRUNNER_TASK_INFO:
        #{s}  ID: <relative_id>
        #{s}  TITLE: <task name>
        #{s}  DESCRIPTION: <first 200 chars of description, or full if shorter>
        #{s}  END_TASK_INFO
      STEP
    end

    def story_task_discovery_steps(story_id:, task_id:)
      <<~STEPS.chomp
        1. LOAD STORY CONTEXT: Read the story to understand the bigger picture
           - Read: workvector://pieces/jchsoft/#{story_id}
           - Review the story name, description, and subtasks list
           - Understand the overall goal and how subtasks relate to each other
           - Note which subtasks are already completed for context
           - You will work on task ##{task_id} (pre-selected by triage)

        2. LOAD TASK DETAILS: Get full task information
           - Read: workvector://pieces/jchsoft/#{task_id}
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
      STEPS
    end

    def create_branch_step(step_num:)
      s = step_indent(step_num)
      <<~STEP.strip
        #{step_num}. CREATE BRANCH: Start work on a new feature branch
        #{s}- ALWAYS include the task ID in the branch name: "feature/{task_id}-{short-description}" or "fix/{task_id}-{short-description}"
        #{s}- Example: "feature/9508-contact-page", "fix/9123-login-bug"
        #{s}- Run: git checkout -b <branch-name>
      STEP
    end

    def implement_task_step(step_num:)
      s = step_indent(step_num)
      <<~STEP.strip
        #{step_num}. IMPLEMENT TASK: Complete the task according to requirements
        #{s}- Follow rules in global CLAUDE.md
        #{s}- Make incremental commits with clear messages
      STEP
    end

    def run_unit_tests_step(step_num:)
      s = step_indent(step_num)
      <<~STEP.strip
        #{step_num}. RUN UNIT TESTS: Execute all unit tests
        #{s}- Use the "test-runner" skill to run tests (invoke /test-runner)
        #{s}- If failures: fix them and commit fixes
        #{s}- Repeat until all pass
      STEP
    end

    def compile_test_assets_step(step_num:)
      s = step_indent(step_num)
      <<~STEP.strip
        #{step_num}. COMPILE TEST ASSETS: Ensure test assets are ready
        #{s}- Run: bin/rails assets:precompile RAILS_ENV=test
        #{s}- This prevents test failures due to missing compiled assets
      STEP
    end

    def prepare_screenshots_step(step_num:, special_method_hint: false)
      s = step_indent(step_num)
      lines = []
      lines << "#{step_num}. PREPARE SCREENSHOTS: Save screenshots for PR review"
      lines << "#{s}- If you created new system tests with visual changes, save screenshots"
      lines << "#{s}- be sure that screenshots shows tested feature, if not - scroll"
      lines << "#{s}- These will be used later for PR"
      lines << "#{s}- may be there is a **special method** for this in ApplicationSystemTestCase" if special_method_hint
      lines.join("\n")
    end

    def run_system_tests_step(step_num:)
      s = step_indent(step_num)
      <<~STEP.strip
        #{step_num}. RUN SYSTEM TESTS: Execute all system tests
        #{s}- Use the "test-runner" skill to run system tests (invoke /test-runner for system tests)
        #{s}- If failures: fix them and commit fixes
        #{s}- Repeat until all pass
      STEP
    end

    def refactor_step(step_num:)
      s = step_indent(step_num)
      <<~STEP.strip
        #{step_num}. REFACTOR: Read global `~/.claude/rules/ruby-rails.md`, then refactor with FOCUS ON ROR RULES
        #{s}- Apply Ruby/Rails best practices
        #{s}- Commit refactoring changes
      STEP
    end

    def verify_tests_step(step_num:)
      s = step_indent(step_num)
      <<~STEP.strip
        #{step_num}. VERIFY TESTS AFTER REFACTOR: Re-run all tests
        #{s}- Use the "test-runner" skill for both unit and system tests
        #{s}- Run unit tests - repeat until all pass
        #{s}- Run system tests - repeat until all pass
      STEP
    end

    def push_step(step_num:, set_upstream: true)
      s = step_indent(step_num)
      push_cmd = set_upstream ? 'git push -u origin HEAD' : 'git push origin HEAD'
      <<~STEP.strip
        #{step_num}. PUSH: Push branch to remote repository
        #{s}- Run: #{push_cmd}
      STEP
    end

    def create_pr_step(step_num:, no_merge_warning: false, auto_merge_note: false)
      s = step_indent(step_num)
      title_suffix = no_merge_warning ? ' (NO MERGE!)' : ''
      lines = []
      lines << "#{step_num}. CREATE PULL REQUEST: Open PR for review#{title_suffix}"
      lines << "#{s}- Use format from .github/pull_request_template.md if exists"
      lines << "#{s}- Include clear summary of changes"
      lines << "#{s}- Link to the task in WorkVector"
      lines << "#{s}- IMPORTANT: Do NOT merge the PR - leave it open for human review" if no_merge_warning
      lines << "#{s}- Note: PR will be automatically merged after CI passes" if auto_merge_note
      lines.join("\n")
    end

    def add_screenshots_to_pr_step(step_num:)
      s = step_indent(step_num)
      <<~STEP.strip
        #{step_num}. ADD SCREENSHOTS TO PR: Add screenshots using skill "pr-screenshot"
        #{s}- make sure the test is not due to some test failure
        #{s}- be sure that screenshots shows tested feature
      STEP
    end

    def skip_screenshots_step(step_num:)
      "#{step_num}. do not add screenshots to PR review - it is autosquash"
    end

    def code_review_step(step_num:)
      s = step_indent(step_num)
      <<~STEP.strip
        #{step_num}. CODE REVIEW: Review the PR using the code-review skill
        #{s}- SKIP this step if your changes ONLY touch test files (no production code modified)
        #{s}- Use the "code-review:code-review" skill to review the pull request (invoke /code-review:code-review)
        #{s}- If the review finds issues:
        #{s}  * Fix all actionable feedback (bugs, missing tests, style issues)
        #{s}  * Commit and push fixes
        #{s}  * Re-run the "code-review:code-review" skill to verify fixes
        #{s}  * Repeat until the review passes cleanly
        #{s}- Only proceed when the code review has no more actionable findings
      STEP
    end

    def preexisting_test_errors_instruction
      <<~INSTRUCTION.strip
        PREEXISTING TEST ERRORS (CRITICAL):
        If during any test step you discover test failures in code you did NOT modify:
        1. Verify: check if the failing tests are in files you never touched,
           or run tests on main branch (git stash, run tests, git stash pop)
        2. If tests fail WITHOUT your changes = PREEXISTING TEST ERRORS
        3. Create an URGENT bug task to fix them:
           - First, get current user ID: read workvector://user and extract the user's relative_id
           - Use mcp__workvector-production__CreatePieceTool with:
             - account_code: "jchsoft"
             - piece_type: "Task"
             - task_type_code: "bug"
             - priority_code: "urgent"
             - project_id: <project_relative_id from CLAUDE.md>
             - assigned_user_id: <relative_id from workvector://user>
             - name: "Fix: Padající testy - <brief description of failures>"
             - description: Include: failing test names, error messages, branch/commit where they fail,
               and note which task was interrupted (task ID + branch name)
        4. CLEANUP: Switch back to main branch before outputting result:
           - Run: git checkout main
           - Do NOT delete the feature branch (it will be resumed later after tests are fixed)
        5. Output status "preexisting_test_errors" in WVRUNNER_RESULT
        6. Do NOT try to fix preexisting errors yourself - focus only on creating the bug task
      INSTRUCTION
    end

    def run_local_ci_step(step_num:, verify_step_ref: nil)
      s = step_indent(step_num)
      lines = []
      lines << "#{step_num}. RUN LOCAL CI: If \"bin/ci\" exists, use the \"ci-runner\" skill"
      lines << "#{s}- This step is MANDATORY - task is INCOMPLETE without CI verification"
      lines << "#{s}- If bin/ci doesn't exist: skip this step"
      lines << "#{s}- If some test in step #{verify_step_ref} failed: skip this step" if verify_step_ref
      lines << "#{s}- Use the \"ci-runner\" skill (invoke /ci-runner)"
      lines.join("\n")
    end
  end
end
