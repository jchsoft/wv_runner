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

  def test_rake_file_defines_manual_namespace
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("namespace :manual do"), "Should define manual namespace"
  end

  def test_rake_file_defines_auto_squash_namespace
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("namespace :auto do"), "Should define auto namespace"
    assert content.include?("namespace :squash do"), "Should define squash namespace inside auto"
  end

  def test_rake_file_defines_run_once_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("MODES = %i[once once_dry today daily review reviews workflow]")
    assert content.include?("execute(mode)")
  end

  def test_rake_file_defines_run_once_dry_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("MODES = %i[once once_dry today daily review reviews workflow]")
    assert content.include?("dry-run")
  end

  def test_rake_file_defines_run_today_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("MODES = %i[once once_dry today daily review reviews workflow]")
    assert content.include?("end of today")
  end

  def test_rake_file_defines_run_daily_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("MODES = %i[once once_dry today daily review reviews workflow]")
    assert content.include?("daily loop")
  end

  def test_rake_file_defines_review_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("MODES = %i[once once_dry today daily review reviews workflow]")
    assert content.include?("PR review feedback")
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
    assert_equal 7, content.scan(/when :(\w+)/).length, "Should have 7 mode descriptions"
  end

  def test_rake_file_defines_manual_workflow_story_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("namespace :workflow do"), "Should define workflow namespace inside manual"
    assert content.include?("task :story"), "Should define story task"
    assert content.include?("[:story_id]"), "Story task should accept story_id argument"
  end

  def test_rake_file_defines_story_task_description
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("Process all tasks in a Story"), "Should have story task description"
    assert content.include?("leave them open for review"), "Should mention leaving PRs open"
  end

  def test_rake_file_story_task_validates_story_id
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("story_id is required"), "Should validate story_id presence"
    assert content.include?("story_id&.positive?"), "Should validate story_id is positive"
  end

  def test_rake_file_story_task_calls_story_helper
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("run_wv_runner_story_task"), "Should call story task helper"
    assert content.include?("execute(:story_manual)"), "Should execute story_manual mode"
  end

  # Tests for auto:squash:story task
  def test_rake_file_defines_auto_squash_story_task
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("namespace :auto do"), "Should define auto namespace"
    assert content.include?("namespace :squash do"), "Should define squash namespace inside auto"
    assert content.include?("task :story"), "Should define story task inside auto:squash"
  end

  def test_rake_file_defines_auto_squash_story_task_description
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("automatic PR squash-merge"), "Should have auto-squash task description"
    assert content.include?("after CI passes"), "Should mention CI passing"
  end

  def test_rake_file_auto_squash_story_task_validates_story_id
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("wv_runner:auto:squash:story[123]"), "Should have usage example with story_id"
  end

  def test_rake_file_auto_squash_story_task_calls_helper
    rake_file = File.join(File.dirname(__FILE__), "..", "lib", "tasks", "wv_runner.rake")
    content = File.read(rake_file)

    assert content.include?("run_wv_runner_auto_squash_story_task"), "Should call auto-squash story task helper"
    assert content.include?("execute(:story_auto_squash)"), "Should execute story_auto_squash mode"
  end
end
