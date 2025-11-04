# frozen_string_literal: true

module WvRunner
  # WaitingStrategy handles sleep periods between task batches based on different conditions
  class WaitingStrategy
    def wait_until_next_day
      puts "[WaitingStrategy] [wait_until_next_day] Calculating next business day at 8 AM..."
      until_time = next_business_day_8am
      puts "[WaitingStrategy] [wait_until_next_day] Next business day: #{until_time.strftime('%A, %Y-%m-%d at %H:%M')}"
      sleep_until(until_time)
    end

    def wait_one_hour
      puts "[WaitingStrategy] [wait_one_hour] No tasks available, will wait 1 hour before retry..."
      puts "[WaitingStrategy] [wait_one_hour] Start time: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "[WaitingStrategy] [wait_one_hour] Resume time: #{(Time.now + 1.hour).strftime('%Y-%m-%d %H:%M:%S')}"
      sleep(3600)
      puts "[WaitingStrategy] [wait_one_hour] 1 hour wait complete, ready to retry"
    end

    private

    def sleep_until(until_time)
      puts "[WaitingStrategy] [sleep_until] Calculating sleep duration..."
      duration_seconds = until_time - Time.now

      if duration_seconds <= 0
        puts "[WaitingStrategy] [sleep_until] Target time already passed, no sleep needed"
        return
      end

      hours = (duration_seconds / 3600).round(2)
      minutes = ((duration_seconds % 3600) / 60).round(0)
      puts "[WaitingStrategy] [sleep_until] Sleeping #{hours}h (#{duration_seconds.to_i} seconds) until #{until_time.strftime('%A, %Y-%m-%d at %H:%M:%S')}"
      puts "[WaitingStrategy] [sleep_until] Start time: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"

      sleep(duration_seconds.to_i)

      puts "[WaitingStrategy] [sleep_until] Sleep complete, woke up at #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    end

    def next_business_day_8am
      puts "[WaitingStrategy] [next_business_day_8am] Finding next business day at 8 AM..."
      tomorrow = (Time.now + 1.day).beginning_of_day + 8.hours
      day_count = 1

      puts "[WaitingStrategy] [next_business_day_8am] Starting candidate: #{tomorrow.strftime('%A, %Y-%m-%d at %H:%M')} (wday=#{tomorrow.wday})"

      until working_day?(tomorrow)
        day_count += 1
        tomorrow += 1.day
        puts "[WaitingStrategy] [next_business_day_8am] Skipping weekend: #{tomorrow.strftime('%A, %Y-%m-%d')} (wday=#{tomorrow.wday})"
      end

      puts "[WaitingStrategy] [next_business_day_8am] Found business day after #{day_count} day(s): #{tomorrow.strftime('%A, %Y-%m-%d at %H:%M')}"
      tomorrow
    end

    def working_day?(date)
      is_working = date.wday != 0 && date.wday != 6 # not Sunday (0) or Saturday (6)
      day_name = date.strftime('%A')
      puts "[WaitingStrategy] [working_day?] Checking #{day_name} (wday=#{date.wday}): is_working_day=#{is_working}"
      is_working
    end
  end
end
