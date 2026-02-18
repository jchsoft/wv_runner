# frozen_string_literal: true

require 'test_helper'

class ClaudeCodeHonestTest < Minitest::Test
  def test_honest_responds_to_run
    honest = WvRunner::ClaudeCode::Honest.new
    assert_respond_to honest, :run
  end

  def test_honest_inherits_from_claude_code_base
    assert WvRunner::ClaudeCode::Honest < WvRunner::ClaudeCodeBase
  end

  def test_honest_uses_opusplan_model
    honest = WvRunner::ClaudeCode::Honest.new
    assert_equal 'opusplan', honest.send(:model_name)
  end

  def test_honest_accepts_edits
    honest = WvRunner::ClaudeCode::Honest.new
    assert honest.send(:accept_edits?)
  end

  def test_instructions_includes_project_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        honest = WvRunner::ClaudeCode::Honest.new
        instructions = honest.send(:build_instructions)
        assert_includes instructions, 'project_relative_id=99'
        assert_includes instructions, 'workvector://pieces/jchsoft/@next'
        assert_includes instructions, 'WVRUNNER_RESULT'
      end
    end
  end

  def test_instructions_includes_git_checkout_main
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        honest = WvRunner::ClaudeCode::Honest.new
        instructions = honest.send(:build_instructions)
        assert_includes instructions, 'git checkout main'
        assert_includes instructions, 'GIT STATE CHECK'
        assert_includes instructions, 'clean, stable state'
      end
    end
  end

  def test_instructions_raises_when_project_id_not_found
    File.stub :exist?, false do
      honest = WvRunner::ClaudeCode::Honest.new
      assert_raises(RuntimeError) do
        honest.send(:build_instructions)
      end
    end
  end

  def test_instructions_includes_task_status_check
    File.stub :exist?, true do
      File.stub :read, "project_relative_id=7\n" do
        honest = WvRunner::ClaudeCode::Honest.new
        instructions = honest.send(:build_instructions)
        assert_includes instructions, 'NOT already started or completed'
      end
    end
  end

  def test_instructions_includes_workflow_steps
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        honest = WvRunner::ClaudeCode::Honest.new
        instructions = honest.send(:build_instructions)
        assert_includes instructions, 'CREATE BRANCH'
        assert_includes instructions, 'IMPLEMENT TASK'
        assert_includes instructions, 'incremental commits'
        assert_includes instructions, 'RUN UNIT TESTS'
        assert_includes instructions, 'RUN SYSTEM TESTS'
        assert_includes instructions, 'PUSH'
        assert_includes instructions, 'CREATE PULL REQUEST'
      end
    end
  end
end

class ClaudeCodeDryTest < Minitest::Test
  def test_dry_responds_to_run
    dry = WvRunner::ClaudeCode::Dry.new
    assert_respond_to dry, :run
  end

  def test_dry_inherits_from_claude_code_base
    assert WvRunner::ClaudeCode::Dry < WvRunner::ClaudeCodeBase
  end

  def test_dry_uses_haiku_model
    dry = WvRunner::ClaudeCode::Dry.new
    assert_equal 'haiku', dry.send(:model_name)
  end

  def test_dry_does_not_accept_edits
    dry = WvRunner::ClaudeCode::Dry.new
    refute dry.send(:accept_edits?)
  end

  def test_instructions_dry_includes_project_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=77' do
        dry = WvRunner::ClaudeCode::Dry.new
        instructions = dry.send(:build_instructions)
        assert_includes instructions, 'project_relative_id=77'
        assert_includes instructions, 'workvector://pieces/jchsoft/@next'
        assert_includes instructions, 'WVRUNNER_RESULT'
        assert_includes instructions, 'DRY RUN'
        assert_includes instructions, 'DO NOT create a branch'
      end
    end
  end

  def test_instructions_dry_includes_task_info_fields
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=77' do
        dry = WvRunner::ClaudeCode::Dry.new
        instructions = dry.send(:build_instructions)
        assert_includes instructions, 'task_info'
        assert_includes instructions, 'name'
        assert_includes instructions, 'description'
        assert_includes instructions, 'status'
        assert_includes instructions, 'priority'
      end
    end
  end

  def test_instructions_dry_raises_when_project_id_not_found
    File.stub :exist?, false do
      dry = WvRunner::ClaudeCode::Dry.new
      assert_raises(RuntimeError) do
        dry.send(:build_instructions)
      end
    end
  end

  def test_instructions_dry_includes_duration_best_extraction
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=77' do
        dry = WvRunner::ClaudeCode::Dry.new
        instructions = dry.send(:build_instructions)
        assert_includes instructions, 'duration_best'
        assert_includes instructions, 'hodina'
        assert_includes instructions, 'den'
        assert_includes instructions, 'DEBUG'
        assert_includes instructions, 'task_estimated: Y'
      end
    end
  end

  def test_instructions_dry_prevents_modifications
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=77' do
        dry = WvRunner::ClaudeCode::Dry.new
        instructions = dry.send(:build_instructions)
        assert_includes instructions, 'DO NOT create a branch'
        assert_includes instructions, 'DO NOT modify any code'
        assert_includes instructions, 'DO NOT create a pull request'
      end
    end
  end
end

class ClaudeCodeReviewTest < Minitest::Test
  def test_review_responds_to_run
    review = WvRunner::ClaudeCode::Review.new
    assert_respond_to review, :run
  end

  def test_review_inherits_from_claude_code_base
    assert WvRunner::ClaudeCode::Review < WvRunner::ClaudeCodeBase
  end

  def test_review_uses_sonnet_model
    review = WvRunner::ClaudeCode::Review.new
    assert_equal 'sonnet', review.send(:model_name)
  end

  def test_review_accepts_edits
    review = WvRunner::ClaudeCode::Review.new
    assert review.send(:accept_edits?)
  end

  def test_review_instructions_includes_git_state_check
    review = WvRunner::ClaudeCode::Review.new
    instructions = review.send(:build_instructions)
    assert_includes instructions, 'GIT STATE CHECK'
    assert_includes instructions, 'NOT on main/master branch'
    assert_includes instructions, 'git branch --show-current'
  end

  def test_review_instructions_includes_pr_check
    review = WvRunner::ClaudeCode::Review.new
    instructions = review.send(:build_instructions)
    assert_includes instructions, 'PR EXISTENCE CHECK'
    assert_includes instructions, 'gh pr view'
  end

  def test_review_instructions_includes_review_loading
    review = WvRunner::ClaudeCode::Review.new
    instructions = review.send(:build_instructions)
    assert_includes instructions, 'LOAD REVIEW COMMENTS'
    assert_includes instructions, 'human review'
    assert_includes instructions, 'pulls/{pr_number}/reviews'
    assert_includes instructions, 'pulls/{pr_number}/comments'
  end

  def test_review_instructions_includes_fix_workflow
    review = WvRunner::ClaudeCode::Review.new
    instructions = review.send(:build_instructions)
    assert_includes instructions, 'FIX REVIEW ISSUES'
    assert_includes instructions, 'COMMIT CHANGES'
    assert_includes instructions, 'RUN UNIT TESTS'
    assert_includes instructions, 'RUN SYSTEM TESTS'
    assert_includes instructions, 'PUSH'
  end

  def test_review_instructions_includes_wvrunner_result
    review = WvRunner::ClaudeCode::Review.new
    instructions = review.send(:build_instructions)
    assert_includes instructions, 'WVRUNNER_RESULT'
    assert_includes instructions, 'status'
    assert_includes instructions, 'hours'
  end

  def test_review_instructions_includes_status_values
    review = WvRunner::ClaudeCode::Review.new
    instructions = review.send(:build_instructions)
    assert_includes instructions, 'success'
    assert_includes instructions, 'no_reviews'
    assert_includes instructions, 'not_on_branch'
    assert_includes instructions, 'no_pr'
    assert_includes instructions, 'failure'
  end

  def test_review_instructions_includes_workvector_task_extraction
    review = WvRunner::ClaudeCode::Review.new
    instructions = review.send(:build_instructions)
    assert_includes instructions, 'EXTRACT TASK INFO'
    assert_includes instructions, 'workvector.com'
  end

  def test_review_instructions_includes_subtask_creation
    review = WvRunner::ClaudeCode::Review.new
    instructions = review.send(:build_instructions)
    assert_includes instructions, 'CREATE SUBTASK'
    assert_includes instructions, 'CreatePieceTool'
  end
end

class ClaudeCodeReviewsTest < Minitest::Test
  def test_reviews_responds_to_run
    reviews = WvRunner::ClaudeCode::Reviews.new
    assert_respond_to reviews, :run
  end

  def test_reviews_inherits_from_review
    assert WvRunner::ClaudeCode::Reviews < WvRunner::ClaudeCode::Review
  end

  def test_reviews_uses_sonnet_model
    reviews = WvRunner::ClaudeCode::Reviews.new
    assert_equal 'sonnet', reviews.send(:model_name)
  end

  def test_reviews_accepts_edits
    reviews = WvRunner::ClaudeCode::Reviews.new
    assert reviews.send(:accept_edits?)
  end

  def test_reviews_instructions_includes_find_next_pr_step
    reviews = WvRunner::ClaudeCode::Reviews.new
    instructions = reviews.send(:build_instructions)
    assert_includes instructions, 'FIND NEXT PR WITH REVIEW'
    assert_includes instructions, 'gh pr list'
    assert_includes instructions, '--state open'
  end

  def test_reviews_instructions_includes_checkout_branch
    reviews = WvRunner::ClaudeCode::Reviews.new
    instructions = reviews.send(:build_instructions)
    assert_includes instructions, 'CHECKOUT BRANCH'
    assert_includes instructions, 'git fetch'
    assert_includes instructions, 'git checkout'
  end

  def test_reviews_mentions_called_repeatedly_in_loop
    reviews = WvRunner::ClaudeCode::Reviews.new
    instructions = reviews.send(:build_instructions)
    assert_includes instructions, 'called repeatedly in a loop'
  end

  def test_reviews_instructions_includes_fix_workflow
    reviews = WvRunner::ClaudeCode::Reviews.new
    instructions = reviews.send(:build_instructions)
    assert_includes instructions, 'FIX REVIEW ISSUES'
    assert_includes instructions, 'COMMIT CHANGES'
    assert_includes instructions, 'RUN UNIT TESTS'
    assert_includes instructions, 'RUN SYSTEM TESTS'
    assert_includes instructions, 'PUSH'
  end

  def test_reviews_instructions_includes_wvrunner_result
    reviews = WvRunner::ClaudeCode::Reviews.new
    instructions = reviews.send(:build_instructions)
    assert_includes instructions, 'WVRUNNER_RESULT'
    assert_includes instructions, 'status'
    assert_includes instructions, 'hours'
  end

  def test_reviews_has_different_task_section_than_review
    review = WvRunner::ClaudeCode::Review.new
    reviews = WvRunner::ClaudeCode::Reviews.new

    review_task = review.send(:task_section)
    reviews_task = reviews.send(:task_section)

    refute_equal review_task, reviews_task
    assert_includes reviews_task, 'NEXT Pull Request'
  end

  def test_reviews_handles_single_pr_per_call
    reviews = WvRunner::ClaudeCode::Reviews.new
    instructions = reviews.send(:build_instructions)
    # Reviews now handles single PR per call, loop is in WorkLoop
    refute_includes instructions, 'not_on_branch'  # Does not check current branch
    refute_includes instructions, 'no_pr'  # Does not check current PR existence
    assert_includes instructions, 'FIRST PR'  # Finds first PR with reviews
  end
end

class ClaudeCodeStoryAutoSquashTest < Minitest::Test
  def test_story_auto_squash_responds_to_run
    story_auto_squash = WvRunner::ClaudeCode::StoryAutoSquash.new(story_id: 123)
    assert_respond_to story_auto_squash, :run
  end

  def test_story_auto_squash_inherits_from_claude_code_base
    assert WvRunner::ClaudeCode::StoryAutoSquash < WvRunner::ClaudeCodeBase
  end

  def test_story_auto_squash_uses_opusplan_model
    story_auto_squash = WvRunner::ClaudeCode::StoryAutoSquash.new(story_id: 123)
    assert_equal 'opusplan', story_auto_squash.send(:model_name)
  end

  def test_story_auto_squash_accepts_edits
    story_auto_squash = WvRunner::ClaudeCode::StoryAutoSquash.new(story_id: 123)
    assert story_auto_squash.send(:accept_edits?)
  end

  def test_story_auto_squash_requires_story_id
    assert_raises(ArgumentError) do
      WvRunner::ClaudeCode::StoryAutoSquash.new
    end
  end

  def test_story_auto_squash_instructions_includes_story_id
    story_auto_squash = WvRunner::ClaudeCode::StoryAutoSquash.new(story_id: 456)
    instructions = story_auto_squash.send(:build_instructions)
    assert_includes instructions, 'Story #456'
    assert_includes instructions, 'workvector://pieces/jchsoft/456'
  end

  def test_story_auto_squash_instructions_includes_load_story_step
    story_auto_squash = WvRunner::ClaudeCode::StoryAutoSquash.new(story_id: 123)
    instructions = story_auto_squash.send(:build_instructions)
    assert_includes instructions, 'LOAD STORY'
    assert_includes instructions, 'subtasks array'
    assert_includes instructions, 'NOT "Schváleno"'
    assert_includes instructions, 'NOT "Hotovo?"'
    assert_includes instructions, 'progress < 100'
  end

  def test_story_auto_squash_instructions_includes_workflow_steps
    story_auto_squash = WvRunner::ClaudeCode::StoryAutoSquash.new(story_id: 123)
    instructions = story_auto_squash.send(:build_instructions)
    assert_includes instructions, 'GIT STATE CHECK'
    assert_includes instructions, 'git checkout main'
    assert_includes instructions, 'CREATE BRANCH'
    assert_includes instructions, 'IMPLEMENT TASK'
    assert_includes instructions, 'RUN UNIT TESTS'
    assert_includes instructions, 'RUN SYSTEM TESTS'
    assert_includes instructions, 'REFACTOR'
    assert_includes instructions, 'PUSH'
    assert_includes instructions, 'CREATE PULL REQUEST'
  end

  def test_story_auto_squash_instructions_includes_auto_merge
    story_auto_squash = WvRunner::ClaudeCode::StoryAutoSquash.new(story_id: 123)
    instructions = story_auto_squash.send(:build_instructions)
    assert_includes instructions, 'AUTO-SQUASH'
    assert_includes instructions, 'gh pr merge --squash --delete-branch'
    assert_includes instructions, 'automatically merged after CI passes'
  end

  def test_story_auto_squash_instructions_includes_ci_retry_logic
    story_auto_squash = WvRunner::ClaudeCode::StoryAutoSquash.new(story_id: 123)
    instructions = story_auto_squash.send(:build_instructions)
    assert_includes instructions, 'bin/ci'
    assert_includes instructions, 'IF CI FAILS (first attempt)'
    assert_includes instructions, 'Retry CI'
    assert_includes instructions, 'IF RETRY FAILS'
    assert_includes instructions, 'ci_failed'
  end

  def test_story_auto_squash_instructions_includes_wvrunner_result
    story_auto_squash = WvRunner::ClaudeCode::StoryAutoSquash.new(story_id: 789)
    instructions = story_auto_squash.send(:build_instructions)
    assert_includes instructions, 'WVRUNNER_RESULT'
    assert_includes instructions, 'story_id'
    assert_includes instructions, '789'
    assert_includes instructions, 'task_id'
  end

  def test_story_auto_squash_instructions_includes_status_values
    story_auto_squash = WvRunner::ClaudeCode::StoryAutoSquash.new(story_id: 123)
    instructions = story_auto_squash.send(:build_instructions)
    assert_includes instructions, 'success'
    assert_includes instructions, 'no_more_tasks'
    assert_includes instructions, 'ci_failed'
    assert_includes instructions, 'failure'
  end

  def test_story_auto_squash_instructions_includes_compile_assets_step
    story_auto_squash = WvRunner::ClaudeCode::StoryAutoSquash.new(story_id: 123)
    instructions = story_auto_squash.send(:build_instructions)
    assert_includes instructions, 'COMPILE TEST ASSETS'
    assert_includes instructions, 'assets:precompile'
  end
end

class ClaudeCodeTodayAutoSquashTest < Minitest::Test
  def test_today_auto_squash_responds_to_run
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        today_auto_squash = WvRunner::ClaudeCode::TodayAutoSquash.new
        assert_respond_to today_auto_squash, :run
      end
    end
  end

  def test_today_auto_squash_inherits_from_claude_code_base
    assert WvRunner::ClaudeCode::TodayAutoSquash < WvRunner::ClaudeCodeBase
  end

  def test_today_auto_squash_uses_opusplan_model
    today_auto_squash = WvRunner::ClaudeCode::TodayAutoSquash.new
    assert_equal 'opusplan', today_auto_squash.send(:model_name)
  end

  def test_today_auto_squash_accepts_edits
    today_auto_squash = WvRunner::ClaudeCode::TodayAutoSquash.new
    assert today_auto_squash.send(:accept_edits?)
  end

  def test_today_auto_squash_instructions_includes_project_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        today_auto_squash = WvRunner::ClaudeCode::TodayAutoSquash.new
        instructions = today_auto_squash.send(:build_instructions)
        assert_includes instructions, 'project_relative_id=99'
        assert_includes instructions, 'workvector://pieces/jchsoft/@next'
      end
    end
  end

  def test_today_auto_squash_instructions_includes_git_checkout_main
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        today_auto_squash = WvRunner::ClaudeCode::TodayAutoSquash.new
        instructions = today_auto_squash.send(:build_instructions)
        assert_includes instructions, 'git checkout main'
        assert_includes instructions, 'GIT STATE CHECK'
      end
    end
  end

  def test_today_auto_squash_instructions_includes_workflow_steps
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        today_auto_squash = WvRunner::ClaudeCode::TodayAutoSquash.new
        instructions = today_auto_squash.send(:build_instructions)
        assert_includes instructions, 'CREATE BRANCH'
        assert_includes instructions, 'IMPLEMENT TASK'
        assert_includes instructions, 'RUN UNIT TESTS'
        assert_includes instructions, 'RUN SYSTEM TESTS'
        assert_includes instructions, 'REFACTOR'
        assert_includes instructions, 'PUSH'
        assert_includes instructions, 'CREATE PULL REQUEST'
      end
    end
  end

  def test_today_auto_squash_instructions_includes_auto_merge
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        today_auto_squash = WvRunner::ClaudeCode::TodayAutoSquash.new
        instructions = today_auto_squash.send(:build_instructions)
        assert_includes instructions, 'AUTO-SQUASH'
        assert_includes instructions, 'gh pr merge --squash --delete-branch'
        assert_includes instructions, 'automatically merged after CI passes'
      end
    end
  end

  def test_today_auto_squash_instructions_includes_ci_retry_logic
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        today_auto_squash = WvRunner::ClaudeCode::TodayAutoSquash.new
        instructions = today_auto_squash.send(:build_instructions)
        assert_includes instructions, 'bin/ci'
        assert_includes instructions, 'IF CI FAILS (first attempt)'
        assert_includes instructions, 'Retry CI'
        assert_includes instructions, 'IF RETRY FAILS'
        assert_includes instructions, 'ci_failed'
      end
    end
  end

  def test_today_auto_squash_instructions_includes_wvrunner_result
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        today_auto_squash = WvRunner::ClaudeCode::TodayAutoSquash.new
        instructions = today_auto_squash.send(:build_instructions)
        assert_includes instructions, 'WVRUNNER_RESULT'
        assert_includes instructions, 'status'
        assert_includes instructions, 'hours'
      end
    end
  end

  def test_today_auto_squash_instructions_includes_status_values
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        today_auto_squash = WvRunner::ClaudeCode::TodayAutoSquash.new
        instructions = today_auto_squash.send(:build_instructions)
        assert_includes instructions, 'success'
        assert_includes instructions, 'no_more_tasks'
        assert_includes instructions, 'ci_failed'
        assert_includes instructions, 'failure'
      end
    end
  end

  def test_today_auto_squash_instructions_includes_compile_assets_step
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        today_auto_squash = WvRunner::ClaudeCode::TodayAutoSquash.new
        instructions = today_auto_squash.send(:build_instructions)
        assert_includes instructions, 'COMPILE TEST ASSETS'
        assert_includes instructions, 'assets:precompile'
      end
    end
  end

  def test_today_auto_squash_raises_when_project_id_not_found
    File.stub :exist?, false do
      today_auto_squash = WvRunner::ClaudeCode::TodayAutoSquash.new
      assert_raises(RuntimeError) do
        today_auto_squash.send(:build_instructions)
      end
    end
  end
end

class ClaudeCodeStoryManualTest < Minitest::Test
  def test_story_manual_responds_to_run
    story_manual = WvRunner::ClaudeCode::StoryManual.new(story_id: 123)
    assert_respond_to story_manual, :run
  end

  def test_story_manual_inherits_from_claude_code_base
    assert WvRunner::ClaudeCode::StoryManual < WvRunner::ClaudeCodeBase
  end

  def test_story_manual_uses_opusplan_model
    story_manual = WvRunner::ClaudeCode::StoryManual.new(story_id: 123)
    assert_equal 'opusplan', story_manual.send(:model_name)
  end

  def test_story_manual_accepts_edits
    story_manual = WvRunner::ClaudeCode::StoryManual.new(story_id: 123)
    assert story_manual.send(:accept_edits?)
  end

  def test_story_manual_requires_story_id
    assert_raises(ArgumentError) do
      WvRunner::ClaudeCode::StoryManual.new
    end
  end

  def test_story_manual_instructions_includes_story_id
    story_manual = WvRunner::ClaudeCode::StoryManual.new(story_id: 456)
    instructions = story_manual.send(:build_instructions)
    assert_includes instructions, 'Story #456'
    assert_includes instructions, 'workvector://pieces/jchsoft/456'
  end

  def test_story_manual_instructions_includes_load_story_step
    story_manual = WvRunner::ClaudeCode::StoryManual.new(story_id: 123)
    instructions = story_manual.send(:build_instructions)
    assert_includes instructions, 'LOAD STORY'
    assert_includes instructions, 'subtasks array'
    assert_includes instructions, 'NOT "Schváleno"'
    assert_includes instructions, 'NOT "Hotovo?"'
    assert_includes instructions, 'progress < 100'
  end

  def test_story_manual_instructions_includes_load_task_details_step
    story_manual = WvRunner::ClaudeCode::StoryManual.new(story_id: 123)
    instructions = story_manual.send(:build_instructions)
    assert_includes instructions, 'LOAD TASK DETAILS'
    assert_includes instructions, 'task_relative_id'
    assert_includes instructions, 'WVRUNNER_TASK_INFO'
  end

  def test_story_manual_instructions_includes_workflow_steps
    story_manual = WvRunner::ClaudeCode::StoryManual.new(story_id: 123)
    instructions = story_manual.send(:build_instructions)
    assert_includes instructions, 'GIT STATE CHECK'
    assert_includes instructions, 'git checkout main'
    assert_includes instructions, 'CREATE BRANCH'
    assert_includes instructions, 'IMPLEMENT TASK'
    assert_includes instructions, 'RUN UNIT TESTS'
    assert_includes instructions, 'RUN SYSTEM TESTS'
    assert_includes instructions, 'REFACTOR'
    assert_includes instructions, 'PUSH'
    assert_includes instructions, 'CREATE PULL REQUEST'
  end

  def test_story_manual_instructions_emphasizes_no_merge
    story_manual = WvRunner::ClaudeCode::StoryManual.new(story_id: 123)
    instructions = story_manual.send(:build_instructions)
    assert_includes instructions, 'NO MERGE'
    assert_includes instructions, 'MANUAL workflow'
    assert_includes instructions, 'leave it open for human review'
    assert_includes instructions, 'Human will review and merge'
  end

  def test_story_manual_instructions_includes_wvrunner_result
    story_manual = WvRunner::ClaudeCode::StoryManual.new(story_id: 789)
    instructions = story_manual.send(:build_instructions)
    assert_includes instructions, 'WVRUNNER_RESULT'
    assert_includes instructions, 'story_id'
    assert_includes instructions, '789'
    assert_includes instructions, 'task_id'
  end

  def test_story_manual_instructions_includes_status_values
    story_manual = WvRunner::ClaudeCode::StoryManual.new(story_id: 123)
    instructions = story_manual.send(:build_instructions)
    assert_includes instructions, 'success'
    assert_includes instructions, 'no_more_tasks'
    assert_includes instructions, 'failure'
  end

  def test_story_manual_instructions_includes_ci_step
    story_manual = WvRunner::ClaudeCode::StoryManual.new(story_id: 123)
    instructions = story_manual.send(:build_instructions)
    assert_includes instructions, 'RUN LOCAL CI'
    assert_includes instructions, 'bin/ci'
    assert_includes instructions, 'run_in_background'
  end

  def test_story_manual_instructions_includes_screenshot_steps
    story_manual = WvRunner::ClaudeCode::StoryManual.new(story_id: 123)
    instructions = story_manual.send(:build_instructions)
    assert_includes instructions, 'PREPARE SCREENSHOTS'
    assert_includes instructions, 'ADD SCREENSHOTS TO PR'
    assert_includes instructions, 'pr-screenshot'
  end
end

class ClaudeCodeQueueAutoSquashTest < Minitest::Test
  def test_queue_auto_squash_responds_to_run
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
        assert_respond_to queue_auto_squash, :run
      end
    end
  end

  def test_queue_auto_squash_inherits_from_claude_code_base
    assert WvRunner::ClaudeCode::QueueAutoSquash < WvRunner::ClaudeCodeBase
  end

  def test_queue_auto_squash_uses_opus_model
    queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
    assert_equal 'opus', queue_auto_squash.send(:model_name)
  end

  def test_queue_auto_squash_accepts_edits
    queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
    assert queue_auto_squash.send(:accept_edits?)
  end

  def test_queue_auto_squash_instructions_includes_project_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
        instructions = queue_auto_squash.send(:build_instructions)
        assert_includes instructions, 'project_relative_id=99'
        assert_includes instructions, 'workvector://pieces/jchsoft/@next'
      end
    end
  end

  def test_queue_auto_squash_instructions_includes_git_checkout_main
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
        instructions = queue_auto_squash.send(:build_instructions)
        assert_includes instructions, 'git checkout main'
        assert_includes instructions, 'GIT STATE CHECK'
      end
    end
  end

  def test_queue_auto_squash_instructions_includes_workflow_steps
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
        instructions = queue_auto_squash.send(:build_instructions)
        assert_includes instructions, 'CREATE BRANCH'
        assert_includes instructions, 'IMPLEMENT TASK'
        assert_includes instructions, 'RUN UNIT TESTS'
        assert_includes instructions, 'RUN SYSTEM TESTS'
        assert_includes instructions, 'REFACTOR'
        assert_includes instructions, 'PUSH'
        assert_includes instructions, 'CREATE PULL REQUEST'
      end
    end
  end

  def test_queue_auto_squash_instructions_includes_auto_merge
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
        instructions = queue_auto_squash.send(:build_instructions)
        assert_includes instructions, 'AUTO-SQUASH'
        assert_includes instructions, 'gh pr merge --squash --delete-branch'
        assert_includes instructions, 'automatically merged after CI passes'
      end
    end
  end

  def test_queue_auto_squash_instructions_mentions_queue_mode
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
        instructions = queue_auto_squash.send(:build_instructions)
        assert_includes instructions, 'QUEUE mode'
        assert_includes instructions, '24/7'
        assert_includes instructions, 'without quota checks'
      end
    end
  end

  def test_queue_auto_squash_instructions_includes_ci_retry_logic
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
        instructions = queue_auto_squash.send(:build_instructions)
        assert_includes instructions, 'bin/ci'
        assert_includes instructions, 'IF CI FAILS (first attempt)'
        assert_includes instructions, 'Retry CI'
        assert_includes instructions, 'IF RETRY FAILS'
        assert_includes instructions, 'ci_failed'
      end
    end
  end

  def test_queue_auto_squash_instructions_includes_wvrunner_result
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
        instructions = queue_auto_squash.send(:build_instructions)
        assert_includes instructions, 'WVRUNNER_RESULT'
        assert_includes instructions, 'status'
        assert_includes instructions, 'hours'
      end
    end
  end

  def test_queue_auto_squash_instructions_includes_status_values
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
        instructions = queue_auto_squash.send(:build_instructions)
        assert_includes instructions, 'success'
        assert_includes instructions, 'no_more_tasks'
        assert_includes instructions, 'ci_failed'
        assert_includes instructions, 'failure'
      end
    end
  end

  def test_queue_auto_squash_instructions_includes_compile_assets_step
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
        instructions = queue_auto_squash.send(:build_instructions)
        assert_includes instructions, 'COMPILE TEST ASSETS'
        assert_includes instructions, 'assets:precompile'
      end
    end
  end

  def test_queue_auto_squash_raises_when_project_id_not_found
    File.stub :exist?, false do
      queue_auto_squash = WvRunner::ClaudeCode::QueueAutoSquash.new
      assert_raises(RuntimeError) do
        queue_auto_squash.send(:build_instructions)
      end
    end
  end
end

class ClaudeCodeOnceAutoSquashTest < Minitest::Test
  def test_once_auto_squash_responds_to_run
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
        assert_respond_to once_auto_squash, :run
      end
    end
  end

  def test_once_auto_squash_inherits_from_claude_code_base
    assert WvRunner::ClaudeCode::OnceAutoSquash < WvRunner::ClaudeCodeBase
  end

  def test_once_auto_squash_uses_opus_model
    once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
    assert_equal 'opus', once_auto_squash.send(:model_name)
  end

  def test_once_auto_squash_accepts_edits
    once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
    assert once_auto_squash.send(:accept_edits?)
  end

  def test_once_auto_squash_instructions_includes_project_id
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
        instructions = once_auto_squash.send(:build_instructions)
        assert_includes instructions, 'project_relative_id=99'
        assert_includes instructions, 'workvector://pieces/jchsoft/@next'
      end
    end
  end

  def test_once_auto_squash_instructions_includes_git_checkout_main
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
        instructions = once_auto_squash.send(:build_instructions)
        assert_includes instructions, 'git checkout main'
        assert_includes instructions, 'GIT STATE CHECK'
      end
    end
  end

  def test_once_auto_squash_instructions_includes_workflow_steps
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
        instructions = once_auto_squash.send(:build_instructions)
        assert_includes instructions, 'CREATE BRANCH'
        assert_includes instructions, 'IMPLEMENT TASK'
        assert_includes instructions, 'RUN UNIT TESTS'
        assert_includes instructions, 'RUN SYSTEM TESTS'
        assert_includes instructions, 'REFACTOR'
        assert_includes instructions, 'PUSH'
        assert_includes instructions, 'CREATE PULL REQUEST'
      end
    end
  end

  def test_once_auto_squash_instructions_includes_auto_merge
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
        instructions = once_auto_squash.send(:build_instructions)
        assert_includes instructions, 'AUTO-SQUASH'
        assert_includes instructions, 'gh pr merge --squash --delete-branch'
        assert_includes instructions, 'automatically merged after CI passes'
      end
    end
  end

  def test_once_auto_squash_instructions_mentions_once_mode
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
        instructions = once_auto_squash.send(:build_instructions)
        assert_includes instructions, 'ONCE mode'
        assert_includes instructions, 'exactly once'
      end
    end
  end

  def test_once_auto_squash_instructions_includes_ci_retry_logic
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
        instructions = once_auto_squash.send(:build_instructions)
        assert_includes instructions, 'bin/ci'
        assert_includes instructions, 'IF CI FAILS (first attempt)'
        assert_includes instructions, 'Retry CI'
        assert_includes instructions, 'IF RETRY FAILS'
        assert_includes instructions, 'ci_failed'
      end
    end
  end

  def test_once_auto_squash_instructions_includes_wvrunner_result
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
        instructions = once_auto_squash.send(:build_instructions)
        assert_includes instructions, 'WVRUNNER_RESULT'
        assert_includes instructions, 'status'
        assert_includes instructions, 'hours'
      end
    end
  end

  def test_once_auto_squash_instructions_includes_status_values
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
        instructions = once_auto_squash.send(:build_instructions)
        assert_includes instructions, 'success'
        assert_includes instructions, 'no_more_tasks'
        assert_includes instructions, 'ci_failed'
        assert_includes instructions, 'failure'
      end
    end
  end

  def test_once_auto_squash_instructions_includes_compile_assets_step
    File.stub :exist?, true do
      File.stub :read, 'project_relative_id=99' do
        once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
        instructions = once_auto_squash.send(:build_instructions)
        assert_includes instructions, 'COMPILE TEST ASSETS'
        assert_includes instructions, 'assets:precompile'
      end
    end
  end

  def test_once_auto_squash_raises_when_project_id_not_found
    File.stub :exist?, false do
      once_auto_squash = WvRunner::ClaudeCode::OnceAutoSquash.new
      assert_raises(RuntimeError) do
        once_auto_squash.send(:build_instructions)
      end
    end
  end
end
