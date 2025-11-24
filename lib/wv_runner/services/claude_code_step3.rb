# frozen_string_literal: true

require_relative 'claude_code_base'

module WvRunner
  class ClaudeCodeStep3 < ClaudeCodeBase
    def model_name
      'haiku'
    end

    private

    def build_instructions(input_state = nil)
      project_relative_id or raise 'project_relative_id not found in CLAUDE.md'
      input_state ? JSON.generate(input_state) : 'null'

      <<~INSTRUCTIONS
        STEP 3: PUSH AND CREATE PULL REQUEST
        This is the THIRD and final step in a multi-step workflow.

        INPUT STATE FROM PREVIOUS STEP:
        {{WORKFLOW_STATE}}

        WORKFLOW:
        1. GIT: Verify you're on the correct branch from Step 2
        2. FINAL TEST VERIFICATION - run all tests one more time
        3. COMMIT any remaining changes with message: "Step 3: Final cleanup and PR preparation"
        4. RUN RUBOCOP on modified files ONLY (NOT entire codebase)
        5. PUSH the branch to remote repository
        6. CREATE A PULL REQUEST using GitHub CLI
        7. EXTRACT PR URL from the gh pr create output
        8. LOG WORK to the task with 90% progress

        At the END, output JSON in this exact format:

        ```json
        WORKFLOW_STATE: {"step": 3, "task_id": <TASK_ID>, "branch_name": "<BRANCH_NAME>", "pr_url": "https://github.com/...", "status": "success", "complete": true}
        ```

        CRITICAL: The JSON MUST be inside triple backticks on a separate line with NO other text after.
      INSTRUCTIONS
    end
  end
end
