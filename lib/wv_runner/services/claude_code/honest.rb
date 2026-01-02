# frozen_string_literal: true

require_relative '../claude_code_base'

module WvRunner
  module ClaudeCode
    # Executes real work - creates branches, modifies code, creates PRs
    class Honest < ClaudeCodeBase
      def model_name
        'opus'
      end

      private

      def build_instructions
        project_id = project_relative_id or raise 'project_relative_id not found in CLAUDE.md'

        <<~INSTRUCTIONS
          [PERSONA]
          You are a senior Ruby On Rails software developer, following RubyWay principles.
          [TASK]
          Work on next task from: workvector://pieces/jchsoft/@next?project_relative_id=#{project_id}

          WORKFLOW:
          1. GIT: Make sure you are on the main branch
             - Run: git checkout main (switch to main branch if not already there)
             - This ensures you start from a clean, stable state
          2. Make sure task is new and **NOT ALREADY STARTED** or completed
          3. CREATE A NEW BRANCH at the start of the task (use task name as branch name, e.g., "feature/task-name" or "fix/issue-name")
          4. COMPLETE the task according to requirements (following rules in global CLAUDE.md)
          5. COMMIT your changes with clear commit messages
          6. MAKE SURE all code changes are properly tested
          7. COMMIT your changes with clear commit messages
          8. **RUN ALL UNIT TESTS repeatedly until they all PASS** - do not make you way easy - tests must be solid and all passing
          9. **PREPARE SCREENSHOT FOR REVIEW** - save screenshot in new systems test to be used later for PR, if you created some
          10. **RUN ALL SYSTEM TESTS repeatedly until they all PASS** - do not make you way easy - tests must be solid and all passing - system tests last longer, even 5 minutes 
          11. COMMIT your changes with clear commit messages
          12. **Read global CLAUDE.md**, then refactor new code with FOCUS ON ROR RULES
          13. **RUN ALL UNIT TESTS repeatedly until they all PASS** after refactoring
          14. **RUN ALL SYSTEM TESTS repeatedly until they all PASS** after refactoring
          15. PUSH the branch to remote repository
          16. CREATE A PULL REQUEST:
             - Use the format from .github/pull_request_template.md if exists
             - Include a clear summary of changes
             - Link to the task in WorkVector
          17. **ADD SCREENSHOTS TO PR COMMENTS** - add them using skill "pr-screenshot"
          18. **RUN LOCAL CI** - if exists "bin/ci" file, run it

          At the END, output JSON in this exact format - on a new line in a code block:

          ```json
          WVRUNNER_RESULT: {"status": "success", "hours": {"per_day": X, "task_estimated": Y}}
          ```

          CRITICAL FORMATTING:
          1. The JSON MUST be inside triple backticks (```json ... ```) on a separate line
          2. Output VALID JSON with proper string escaping. Any quotes in string values must be escaped as \\"
          3. NO other text after the closing triple backticks

          How to get the data:
          1. Read workvector://user -> use "hour_goal" value for per_day
          2. From the task you're working on -> parse "duration_best" field (e.g., "1 hodina" -> 1.0) for task_estimated
          3. Set status:
             - "success" if task completed successfully
             - "no_more_tasks" if no tasks available (workvector returns "No available tasks found")
             - "failure" for other errors
        INSTRUCTIONS
      end
    end
  end
end
