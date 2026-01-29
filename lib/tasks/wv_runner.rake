namespace :wv_runner do
  namespace :manual do
    MODES = %i[once once_dry today daily review reviews workflow queue].freeze

    MODES.each do |mode|
      desc case mode
           when :once
             'Run a single task once (pass verbose=true for verbose output, default: normal mode)'
           when :once_dry
             'Load and display next task information (dry-run, no execution) (pass verbose=true for verbose output, default: normal mode)'
           when :today
             'Run tasks until end of today (pass verbose=true for verbose output, default: normal mode)'
           when :daily
             'Run tasks continuously in a daily loop (pass verbose=true for verbose output, default: normal mode)'
           when :review
             'Handle PR review feedback on current branch (pass verbose=true for verbose output, default: normal mode)'
           when :reviews
             'Find and process all PRs with unaddressed reviews (pass verbose=true for verbose output, default: normal mode)'
           when :workflow
             'Run full workflow: process reviews first, then tasks for today (pass verbose=true for verbose output, default: normal mode)'
           when :queue
             'Process queue continuously without quota checks or auto-merge, PRs stay open for review (pass verbose=true for verbose output, default: normal mode)'
      end
      task mode => :environment do
        run_wv_runner_task(mode)
      end
    end

    namespace :workflow do
      desc 'Process all tasks in a Story, create PRs but leave them open for review (pass story_id as argument)'
      task :story, [:story_id] => :environment do |_t, args|
        story_id = args[:story_id]&.to_i
        raise ArgumentError, 'story_id is required. Usage: rake wv_runner:manual:workflow:story[123]' unless story_id&.positive?

        run_wv_runner_story_task(story_id)
      end
    end
  end

  namespace :auto do
    namespace :squash do
      desc 'Run tasks until quota reached with automatic PR squash-merge after CI passes'
      task today: :environment do
        run_wv_runner_auto_squash_today_task
      end

      desc 'Process all tasks in a Story with automatic PR squash-merge after CI passes'
      task :story, [:story_id] => :environment do |_t, args|
        story_id = args[:story_id]&.to_i
        raise ArgumentError, 'story_id is required. Usage: rake wv_runner:auto:squash:story[123]' unless story_id&.positive?

        run_wv_runner_auto_squash_story_task(story_id)
      end

      desc 'Process queue continuously 24/7 with automatic PR squash-merge after CI passes (no quota checks)'
      task queue: :environment do
        run_wv_runner_auto_squash_queue_task
      end
    end
  end

  private

  def run_wv_runner_task(mode)
    display_version_info
    verbose = verbose_mode_enabled?
    display_output_mode(verbose)
    # Map :queue to :queue_manual for namespace :manual
    execute_mode = mode == :queue ? :queue_manual : mode
    WvRunner::WorkLoop.new(verbose: verbose).execute(execute_mode)
  end

  def run_wv_runner_story_task(story_id)
    display_version_info
    puts "[WvRunner] Story ID: #{story_id}"
    verbose = verbose_mode_enabled?
    display_output_mode(verbose)
    WvRunner::WorkLoop.new(verbose: verbose, story_id: story_id).execute(:story_manual)
  end

  def run_wv_runner_auto_squash_story_task(story_id)
    display_version_info
    puts "[WvRunner] Story ID: #{story_id} (AUTO-SQUASH mode)"
    verbose = verbose_mode_enabled?
    display_output_mode(verbose)
    WvRunner::WorkLoop.new(verbose: verbose, story_id: story_id).execute(:story_auto_squash)
  end

  def run_wv_runner_auto_squash_today_task
    display_version_info
    puts '[WvRunner] AUTO-SQUASH TODAY mode - PRs will be automatically merged after CI passes'
    verbose = verbose_mode_enabled?
    display_output_mode(verbose)
    WvRunner::WorkLoop.new(verbose: verbose).execute(:today_auto_squash)
  end

  def run_wv_runner_auto_squash_queue_task
    display_version_info
    puts '[WvRunner] AUTO-SQUASH QUEUE mode - 24/7 processing without quota checks'
    puts '[WvRunner] PRs will be automatically merged after CI passes'
    verbose = verbose_mode_enabled?
    display_output_mode(verbose)
    WvRunner::WorkLoop.new(verbose: verbose).execute(:queue_auto_squash)
  end

  def verbose_mode_enabled?
    ENV['verbose']&.downcase == 'true'
  end

  def display_version_info
    puts '=' * 80
    puts "[WvRunner] Version: #{WvRunner::VERSION}"
    puts '=' * 80
  end

  def display_output_mode(verbose)
    mode = verbose ? 'VERBOSE' : 'NORMAL'
    puts "[WvRunner] Output mode: #{mode}"
  end
end
