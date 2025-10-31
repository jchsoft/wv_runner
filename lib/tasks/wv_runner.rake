namespace :wv_runner do
  desc 'Run a single task once'
  task run_once: :environment do
    WvRunner::WorkLoop.new.execute(:once)
  end

  desc 'Run tasks until end of today'
  task run_today: :environment do
    WvRunner::WorkLoop.new.execute(:today)
  end

  desc 'Run tasks continuously in a daily loop'
  task run_daily: :environment do
    WvRunner::WorkLoop.new.execute(:daily)
  end
end
