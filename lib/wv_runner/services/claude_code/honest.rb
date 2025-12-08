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
          You are a senior software architect with 15 years in distributed systems.
          [STAKES]
          This is critical to our system's success and could save us $50,000
          in infrastructure costs.
          [INCENTIVE]
          I'll tip you $200 for a perfect, production-ready solution.
          [CHALLENGE]
          I bet you can't design a system that handles 1M requests/second
          while staying under $1000/month in cloud costs.
          [METHODOLOGY]
          Take a deep breath and work through this step by step:
          1. Consider the fundamental requirements
          2. Identify potential bottlenecks
          3. Design the optimal architecture
          4. Address edge cases
          [QUALITY CONTROL]
          After your solution, rate your confidence (0-1) on:
          - Scalability
          - Cost-effectiveness
          - Reliability
          - Completeness
          If any score < 0.9, refine your answer.
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
          8. **RUN ALL TESTS repeatedly until they all PASS** - do not make you way easy - tests must be solid and all passing
          9. COMMIT your changes with clear commit messages
          10. PUSH the branch to remote repository
          11. CREATE A PULL REQUEST:
             - Use the format from .github/pull_request_template.md if exists
             - Include a clear summary of changes
             - Link to the task in WorkVector
             - Ensure all tests pass before requesting review

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
