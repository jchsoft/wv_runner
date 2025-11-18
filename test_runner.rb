#!/usr/bin/env ruby
# frozen_string_literal: true

puts '🧪 Running all wv_runner tests...'
puts '=' * 80

test_files = [
  'test/logger_test.rb',
  'test/railtie_test.rb',
  'test/services/claude_code_base_test.rb',
  'test/services/claude_code_step_tests.rb',
  'test/services/claude_code_test.rb',
  'test/services/daily_scheduler_test.rb',
  'test/services/decider_test.rb',
  'test/services/output_formatter_test.rb',
  'test/services/waiting_strategy_test.rb',
  'test/services/work_loop_test.rb',
  'test/tasks_test.rb',
  'test/test_helper_test.rb',
  'test/version_manager_test.rb',
  'test/wv_runner_test.rb'
]

total_runs = 0
total_assertions = 0
total_failures = 0
total_errors = 0
failed_files = []

test_files.each do |file|
  next unless File.exist?(file)

  puts "\n📝 #{file}"
  output = `ruby -I lib -I test #{file} 2>&1`
  puts output

  # Parse test results
  if output =~ /(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/
    runs = ::Regexp.last_match(1).to_i
    assertions = ::Regexp.last_match(2).to_i
    failures = ::Regexp.last_match(3).to_i
    errors = ::Regexp.last_match(4).to_i

    total_runs += runs
    total_assertions += assertions
    total_failures += failures
    total_errors += errors

    failed_files << file if failures.positive? || errors.positive?
  end
end

puts "\n" + '=' * 80
puts '📊 TOTAL RESULTS:'
puts "   Runs: #{total_runs}"
puts "   Assertions: #{total_assertions}"
puts "   Failures: #{total_failures}"
puts "   Errors: #{total_errors}"

if failed_files.any?
  puts "\n❌ Failed files:"
  failed_files.each { |f| puts "   - #{f}" }
  exit 1
else
  puts "\n✅ All tests passed!"
  exit 0
end
