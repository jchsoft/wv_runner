# frozen_string_literal: true

require_relative 'claude_code_base'

module WvRunner
  class ClaudeCodeStep2 < ClaudeCodeBase
    private

    def build_instructions(input_state = nil)
      project_relative_id or raise 'project_relative_id not found in CLAUDE.md'

      template = <<~INSTRUCTIONS
        STEP 2: REFACTOR AND FIX TESTS
        This is the SECOND step in a multi-step workflow.

        INPUT STATE FROM PREVIOUS STEP:
        {{WORKFLOW_STATE}}

        WORKFLOW:
        1. GIT: Verify you're on the correct branch from Step 1
        2. REVIEW THE CODE from files created in Step 1
        3. REFACTOR CODE according to Ruby/Rails best practices
        4. FIX ALL TESTS - run repeatedly until ALL PASS
        5. COMMIT your changes with message: "Step 2: Refactor code and fix tests"
        6. LOG WORK to the task with 50% progress
        7. DECIDE NEXT STEP - if more work needed: next_step "refactor_and_tests", else "push_and_pr"

        At the END, output JSON in this exact format:

        ```json
        WORKFLOW_STATE: {"step": 2, "task_id": <TASK_ID>, "branch_name": "<BRANCH_NAME>", "status": "success", "tests_passing": true, "next_step": "push_and_pr"}
        ```

        CRITICAL: The JSON MUST be inside triple backticks on a separate line with NO other text after.
      INSTRUCTIONS

      inject_state_into_instructions(template, input_state)
    end
  end
end
