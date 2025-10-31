require "test_helper"

class TasksTest < Minitest::Test
  def test_rake_file_exists
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    assert File.exist?(rake_file)
  end

  def test_rake_file_is_valid_ruby_syntax
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    # Verify it contains namespace definition
    assert content.include?("namespace :wv_runner do")
  end

  def test_rake_file_defines_run_once_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("task run_once")
    assert content.include?("WorkLoop.new.execute(:once)")
  end

  def test_rake_file_defines_run_today_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("task run_today")
    assert content.include?("WorkLoop.new.execute(:today)")
  end

  def test_rake_file_defines_run_daily_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("task run_daily")
    assert content.include?("WorkLoop.new.execute(:daily)")
  end

  def test_all_tasks_require_environment
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    # Each task should require :environment for Rails context
    tasks = content.scan(/task \w+: :environment/)
    assert_equal 3, tasks.length, "All three tasks should require :environment"
  end

  def test_all_tasks_have_descriptions
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    # Each task should have a desc
    descriptions = content.scan(/desc\s+['"](.*?)['"]/)
    assert_equal 3, descriptions.length, "All three tasks should have descriptions"
  end
end
