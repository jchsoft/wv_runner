# frozen_string_literal: true

require 'test_helper'
require_relative 'triage_test_helper'

class WorkLoopWorkflowTest < Minitest::Test
  include TriageTestHelper

  def test_execute_with_workflow_returns_hash_with_reviews_and_tasks
    reviews_mock = Object.new
    def reviews_mock.run
      { 'status' => 'no_reviews' }
    end

    honest_mock = Object.new
    def honest_mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::Reviews.stub(:new, reviews_mock) do
        WvRunner::ClaudeCode::Honest.stub(:new, honest_mock) do
          loop_instance = WvRunner::WorkLoop.new
          result = loop_instance.execute(:workflow)

          assert_instance_of Hash, result
          assert result.key?('reviews')
          assert result.key?('tasks')
          assert_instance_of Array, result['reviews']
          assert_instance_of Array, result['tasks']
        end
      end
    end
  end

  def test_execute_with_workflow_processes_reviews_first
    reviews_call_order = []

    reviews_mock = Object.new
    reviews_mock.define_singleton_method(:run) do
      reviews_call_order << :reviews
      { 'status' => 'no_reviews' }
    end

    honest_mock = Object.new
    honest_mock.define_singleton_method(:run) do
      reviews_call_order << :honest
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::Reviews.stub(:new, reviews_mock) do
        WvRunner::ClaudeCode::Honest.stub(:new, honest_mock) do
          loop_instance = WvRunner::WorkLoop.new
          loop_instance.execute(:workflow)

          assert_equal :reviews, reviews_call_order.first
        end
      end
    end
  end

  def test_execute_with_workflow_collects_review_results
    reviews_mock = Object.new
    call_count = [0]
    reviews_mock.define_singleton_method(:run) do
      call_count[0] += 1
      call_count[0] == 1 ? { 'status' => 'success', 'pr' => 'PR #1' } : { 'status' => 'no_reviews' }
    end

    honest_mock = Object.new
    def honest_mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::Reviews.stub(:new, reviews_mock) do
        WvRunner::ClaudeCode::Honest.stub(:new, honest_mock) do
          Kernel.stub(:sleep, nil) do
            loop_instance = WvRunner::WorkLoop.new
            result = loop_instance.execute(:workflow)

            assert_equal 2, result['reviews'].length
            assert_equal 'success', result['reviews'].first['status']
            assert_equal 'no_reviews', result['reviews'].last['status']
          end
        end
      end
    end
  end

  def test_execute_with_workflow_collects_task_results
    reviews_mock = Object.new
    def reviews_mock.run
      { 'status' => 'no_reviews' }
    end

    honest_mock = Object.new
    def honest_mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::Reviews.stub(:new, reviews_mock) do
        WvRunner::ClaudeCode::Honest.stub(:new, honest_mock) do
          loop_instance = WvRunner::WorkLoop.new
          result = loop_instance.execute(:workflow)

          assert_equal 1, result['tasks'].length
          assert_equal 'no_more_tasks', result['tasks'].first['status']
        end
      end
    end
  end

  def test_run_today_exits_immediately_on_no_more_tasks
    mock = Object.new
    def mock.run
      { 'status' => 'no_more_tasks', 'hours' => { 'per_day' => 8, 'task_estimated' => 0 } }
    end

    with_triage_stub do
      WvRunner::ClaudeCode::Honest.stub(:new, mock) do
        loop_instance = WvRunner::WorkLoop.new
        results = loop_instance.execute(:today)

        assert_equal 1, results.length
        assert_equal 'no_more_tasks', results.first['status']
      end
    end
  end
end
