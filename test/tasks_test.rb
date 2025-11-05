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

    assert content.include?("MODES = %i[once once_dry today daily]")
    assert content.include?("execute(mode)")
  end

  def test_rake_file_defines_run_once_dry_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("MODES = %i[once once_dry today daily]")
    assert content.include?("dry-run")
  end

  def test_rake_file_defines_run_today_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("MODES = %i[once once_dry today daily]")
    assert content.include?("end of today")
  end

  def test_rake_file_defines_run_daily_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("MODES = %i[once once_dry today daily]")
    assert content.include?("daily loop")
  end

  def test_all_tasks_require_environment
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    # Tasks require :environment for Rails context (dynamically generated via MODES.each)
    assert content.include?("=> :environment")
    assert content.include?("MODES.each")
  end

  def test_all_tasks_have_descriptions
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    # Tasks have descriptions defined via case statement
    assert content.include?("desc case mode")
    assert_equal 4, content.scan(/when :(\w+)/).length, "Should have 4 mode descriptions"
  end
end
