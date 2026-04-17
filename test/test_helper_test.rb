require "test_helper"

class TestHelperTest < Minitest::Test
  def test_minitest_is_loaded
    assert defined?(Minitest::Test)
  end

  def test_minitest_mock_is_available
    mock = Minitest::Mock.new
    mock.expect(:foo, "bar")
    assert_equal "bar", mock.foo
    mock.verify
  end

  def test_mcptask_runner_is_loaded
    assert defined?(McptaskRunner)
  end

  def test_all_services_are_available
    assert defined?(McptaskRunner::ClaudeCode)
    assert defined?(McptaskRunner::ClaudeCode::Honest)
    assert defined?(McptaskRunner::ClaudeCode::Dry)
    assert defined?(McptaskRunner::WorkLoop)
    assert defined?(McptaskRunner::Decider)
  end

  def test_error_class_is_available
    assert defined?(McptaskRunner::Error)
  end

  def test_can_create_service_instances
    assert McptaskRunner::ClaudeCode::Honest.new.is_a?(McptaskRunner::ClaudeCodeBase)
    assert McptaskRunner::ClaudeCode::Dry.new.is_a?(McptaskRunner::ClaudeCodeBase)
    assert McptaskRunner::WorkLoop.new.is_a?(McptaskRunner::WorkLoop)
    assert McptaskRunner::Decider.new.is_a?(McptaskRunner::Decider)
  end
end
