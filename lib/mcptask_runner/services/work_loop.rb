# frozen_string_literal: true

require_relative 'approval_collector'
require_relative 'concerns/triage_execution'
require_relative 'concerns/quota_scheduling'
require_relative 'concerns/loop_strategies'

module McptaskRunner
  # WorkLoop orchestrates Claude Code execution with different modes (once, today, daily)
  # and handles task scheduling with quota management and waiting strategies
  #
  # Concerns:
  #   TriageExecution  — model selection, executor dispatch, story detection
  #   QuotaScheduling  — quota checks, time guards, daily scheduling
  #   LoopStrategies   — all run_* iteration loops
  class WorkLoop
    include Concerns::TriageExecution
    include Concerns::QuotaScheduling
    include Concerns::LoopStrategies

    VALID_HOW_VALUES = %i[once today daily once_dry review reviews workflow story_manual story_auto_squash today_auto_squash queue_auto_squash queue_manual once_auto_squash task_manual task_auto_squash].freeze

    def initialize(verbose: false, story_id: nil, task_id: nil, ignore_quota: false)
      @verbose = verbose
      @story_id = story_id
      @task_id = task_id
      @ignore_quota = ignore_quota
    end

    def execute(how)
      validate_how(how)
      ApprovalCollector.clear

      send("run_#{how}").tap { ApprovalCollector.print_summary }
    end

    private

    def validate_how(how)
      return if VALID_HOW_VALUES.include?(how)

      raise ArgumentError, "Invalid 'how' value: #{how}. Must be one of: #{VALID_HOW_VALUES.join(', ')}"
    end
  end
end
