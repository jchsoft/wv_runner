namespace :wv_runner do
  desc 'Run a single task once'
  task run_once: :environment do
    display_version_info
    WvRunner::WorkLoop.new.execute(:once)
  end

  desc 'Run tasks until end of today'
  task run_today: :environment do
    display_version_info
    WvRunner::WorkLoop.new.execute(:today)
  end

  desc 'Run tasks continuously in a daily loop'
  task run_daily: :environment do
    display_version_info
    WvRunner::WorkLoop.new.execute(:daily)
  end

  private

  def display_version_info
    puts "=" * 80
    puts "[WvRunner] Version: #{WvRunner::VERSION}"
    puts "=" * 80
  end
end
