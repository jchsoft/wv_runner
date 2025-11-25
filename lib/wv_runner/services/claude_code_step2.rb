# frozen_string_literal: true

require_relative 'claude_code_base'

module WvRunner
  class ClaudeCodeStep2 < ClaudeCodeBase
    def model_name
      'haiku'
    end

    private

    def build_instructions(input_state = nil)
      project_relative_id or raise 'project_relative_id not found in CLAUDE.md'

      template = <<~INSTRUCTIONS
        STEP 2: REFACTOR AND FIX TESTS
        This is the SECOND step in a multi-step workflow.

        INPUT STATE FROM PREVIOUS STEP:
        {{WORKFLOW_STATE}}

        CRITICAL REQUIREMENTS FOR THIS STEP:
        - Tests MUST pass before proceeding
        - If tests fail, you MUST request another iteration
        - Tests related to the task are MANDATORY to pass
        - Ideally ALL tests should pass

        WORKFLOW:
        1. GIT: Verify you're on the correct branch from Step 1
        2. REVIEW THE CODE from files created in Step 1
        3. REFACTOR CODE according to Ruby/Rails best practices (check CLAUDE.md for guidelines)
        4. RUN ALL TESTS - This is CRITICAL:
           - First run: ruby test_runner.rb (or appropriate test command)
           - If tests fail, FIX them and RUN AGAIN
           - Keep fixing and running until tests pass
           - Focus especially on tests related to the current task
           - RUN RUBOCOP on modified Ruby files ONLY (NOT entire codebase)
        5. COMMIT your changes with message: "Step 2: Refactor code and fix tests"
        6. LOG WORK with progress between 50% - 80%
        7. DECIDE NEXT STEP based on test results:
           - If tests ARE passing: next_step "push_and_pr"
           - If tests NOT passing: next_step "refactor_and_tests" (to retry)

        At the END, output JSON based on test results:

        If tests PASSED:
        ```json
        WORKFLOW_STATE: {"step": 2, "task_id": <TASK_ID>, "branch_name": "<BRANCH_NAME>", "status": "success", "tests_passing": true, "next_step": "push_and_pr"}
        ```

        If tests FAILED and need retry:
        ```json
        WORKFLOW_STATE: {"step": 2, "task_id": <TASK_ID>, "branch_name": "<BRANCH_NAME>", "status": "success", "tests_passing": false, "next_step": "refactor_and_tests", "retry_reason": "Tests still failing: <brief description>"}
        ```

        IMPORTANT:
        - The runner will retry Step 2 if next_step is "refactor_and_tests"
        - Maximum 3 iterations allowed
        - Be honest about test results - set tests_passing: false if tests fail
        - Include retry_reason to explain what's still failing

        CRITICAL: The JSON MUST be inside triple backticks on a separate line with NO other text after.
      INSTRUCTIONS

      inject_state_into_instructions(template, input_state)
    end
  end
end
