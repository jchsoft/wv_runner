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

  def test_honest_uses_opus_model
    honest = WvRunner::ClaudeCode::Honest.new
    assert_equal 'opus', honest.send(:model_name)
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

  def test_reviews_instructions_includes_find_prs_step
    reviews = WvRunner::ClaudeCode::Reviews.new
    instructions = reviews.send(:build_instructions)
    assert_includes instructions, 'FIND PRS WITH REVIEWS'
    assert_includes instructions, 'gh pr list'
    assert_includes instructions, '--state open'
  end

  def test_reviews_instructions_includes_process_loop
    reviews = WvRunner::ClaudeCode::Reviews.new
    instructions = reviews.send(:build_instructions)
    assert_includes instructions, 'PROCESS PR LOOP'
    assert_includes instructions, 'Process PRs one at a time'
  end

  def test_reviews_instructions_includes_checkout_branch
    reviews = WvRunner::ClaudeCode::Reviews.new
    instructions = reviews.send(:build_instructions)
    assert_includes instructions, 'CHECKOUT BRANCH'
    assert_includes instructions, 'git fetch'
    assert_includes instructions, 'git checkout'
  end

  def test_reviews_instructions_includes_continue_loop
    reviews = WvRunner::ClaudeCode::Reviews.new
    instructions = reviews.send(:build_instructions)
    assert_includes instructions, 'CONTINUE LOOP'
    assert_includes instructions, 'Return to step 2'
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
    assert_includes reviews_task, 'all Pull Requests'
  end

  def test_reviews_status_values_differ_from_review
    reviews = WvRunner::ClaudeCode::Reviews.new
    instructions = reviews.send(:build_instructions)
    assert_includes instructions, 'all reviews addressed'
    refute_includes instructions, 'not_on_branch'
    refute_includes instructions, 'no_pr'
  end
end
