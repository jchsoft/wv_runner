# frozen_string_literal: true

module WvRunner
  # WaitingStrategy handles sleep periods between task batches based on different conditions
  class WaitingStrategy
    def wait_until_next_day
      until_time = next_business_day_8am
      sleep_until(until_time)
    end

    def wait_one_hour
      puts 'No tasks available, waiting 1 hour before retry...'
      sleep(3600)
    end

    private

    def sleep_until(until_time)
      duration_seconds = until_time - Time.now
      return unless duration_seconds.positive?

      hours = (duration_seconds / 3600).round(2)
      puts "Waiting #{hours}h until #{until_time.strftime('%A %Y-%m-%d %H:%M')}"
      sleep(duration_seconds.to_i)
    end

    def next_business_day_8am
      tomorrow = (Time.now + 1.day).beginning_of_day + 8.hours
      tomorrow += 1.day until working_day?(tomorrow)
      tomorrow
    end

    def working_day?(date)
      date.wday != 0 && date.wday != 6 # not Sunday (0) or Saturday (6)
    end
  end
end
