# frozen_string_literal: true

require_relative 'auto_squash_base'

module WvRunner
  module ClaudeCode
    # Processes tasks from @next queue with automatic PR squash-merge after CI passes
    # Similar to run_today but with automatic merge instead of leaving PR open
    class TodayAutoSquash < AutoSquashBase
      def initialize(verbose: false, model_override: nil, task_id: nil, resuming: false)
        super(verbose: verbose, model_override: model_override, resuming: resuming)
        @task_id = task_id
      end

      def model_name = "opus"

      private

      def build_instructions
        build_next_task_instructions(
          task_description: "Work on the next available task with AUTOMATIC PR merge after CI passes.",
          workflow_notice: "IMPORTANT: This is an AUTO-SQUASH workflow - PR is automatically merged after CI passes!\n" \
                          "If CI fails twice, the PR stays open for manual review."
        )
      end
    end
  end
end
