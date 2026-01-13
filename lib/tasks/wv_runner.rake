namespace :wv_runner do
  MODES = %i[once once_dry today daily review reviews].freeze

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
         end
    task mode => :environment do
      run_wv_runner_task(mode)
    end
  end

  private

  def run_wv_runner_task(mode)
    display_version_info
    verbose = verbose_mode_enabled?
    display_output_mode(verbose)
    WvRunner::WorkLoop.new(verbose: verbose).execute(mode)
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
