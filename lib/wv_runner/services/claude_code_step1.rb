# frozen_string_literal: true

require_relative 'claude_code_base'

module WvRunner
  class ClaudeCodeStep1 < ClaudeCodeBase
    private

    def build_instructions(_input_state = nil)
      project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'

      <<~INSTRUCTIONS
        Work on next task from: workvector://pieces/jchsoft/@next?project_relative_id=#{project_id}

        STEP 1: TASK AND PROTOTYPE
        This is the FIRST step in a multi-step workflow.

        WORKFLOW:
        1. GIT: Make sure you are on the main branch
        2. Make sure task is new and NOT ALREADY STARTED or completed
        3. CREATE A NEW BRANCH
        4. IMPLEMENT BASIC FUNCTIONALITY
        5. WRITE BASIC TESTS
        6. COMMIT your changes with message: "Step 1: Task prototype and basic tests"
        7. LOG WORK to the task with 25% progress

        At the END, output JSON in this exact format - on a new line in a code block:

        ```json
        WORKFLOW_STATE: {"step": 1, "task_id": <TASK_ID>, "task_name": "<TASK_NAME>", "branch_name": "<BRANCH_NAME>", "status": "success", "files_created": [], "next_step": "refactor_and_tests"}
        ```

        CRITICAL: The JSON MUST be inside triple backticks (```json ... ```) on a separate line with NO other text after.
      INSTRUCTIONS
    end
  end
end
