namespace :wv_runner do
  desc 'Run a single task once (pass verbose=true for verbose output, default: normal mode)'
  task run_once: :environment do
    display_version_info
    verbose = ENV['verbose']&.downcase == 'true'
    display_output_mode(verbose)
    WvRunner::WorkLoop.new(verbose: verbose).execute(:once)
  end

  desc 'Load and display next task information (dry-run, no execution) (pass verbose=true for verbose output, default: normal mode)'
  task run_once_dry: :environment do
    display_version_info
    verbose = ENV['verbose']&.downcase == 'true'
    display_output_mode(verbose)
    WvRunner::WorkLoop.new(verbose: verbose).execute(:once_dry)
  end

  desc 'Run tasks until end of today (pass verbose=true for verbose output, default: normal mode)'
  task run_today: :environment do
    display_version_info
    verbose = ENV['verbose']&.downcase == 'true'
    display_output_mode(verbose)
    WvRunner::WorkLoop.new(verbose: verbose).execute(:today)
  end

  desc 'Run tasks continuously in a daily loop (pass verbose=true for verbose output, default: normal mode)'
  task run_daily: :environment do
    display_version_info
    verbose = ENV['verbose']&.downcase == 'true'
    display_output_mode(verbose)
    WvRunner::WorkLoop.new(verbose: verbose).execute(:daily)
  end

  private

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
