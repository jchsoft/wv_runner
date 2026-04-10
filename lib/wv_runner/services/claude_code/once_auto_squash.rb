# frozen_string_literal: true

require_relative 'auto_squash_base'

module WvRunner
  module ClaudeCode
    # Processes a single task with automatic PR squash-merge after CI passes
    # Unlike queue_auto_squash, this runs exactly once and exits
    class OnceAutoSquash < AutoSquashBase
      def initialize(verbose: false, model_override: nil, task_id: nil, resuming: false)
        super(verbose: verbose, model_override: model_override, resuming: resuming)
        @task_id = task_id
      end

      def model_name = "opus"

      private

      def build_instructions
        build_next_task_instructions(
          task_description: "Work on the next available task with AUTOMATIC PR merge after CI passes.\n" \
                            "This is ONCE mode - runs exactly once and exits after completing one task.",
          workflow_notice: "IMPORTANT: This is ONCE AUTO-SQUASH workflow - runs exactly once and exits!\n" \
                          "PR is automatically merged after CI passes. If CI fails twice, PR stays open."
        )
      end
    end
  end
end
