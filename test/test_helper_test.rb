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

  def test_wv_runner_is_loaded
    assert defined?(WvRunner)
  end

  def test_all_services_are_available
    assert defined?(WvRunner::ClaudeCode)
    assert defined?(WvRunner::WorkLoop)
    assert defined?(WvRunner::Decider)
  end

  def test_error_class_is_available
    assert defined?(WvRunner::Error)
  end

  def test_can_create_service_instances
    assert WvRunner::ClaudeCode.new.is_a?(WvRunner::ClaudeCode)
    assert WvRunner::WorkLoop.new.is_a?(WvRunner::WorkLoop)
    assert WvRunner::Decider.new.is_a?(WvRunner::Decider)
  end
end
