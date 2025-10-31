require "test_helper"

class WvRunnerTest < Minitest::Test
  def test_module_exists
    assert defined?(WvRunner)
  end

  def test_error_inherits_from_standard_error
    assert WvRunner::Error < StandardError
  end

  def test_can_raise_wv_runner_error
    assert_raises(WvRunner::Error) do
      raise WvRunner::Error, "Test error"
    end
  end

  def test_work_loop_is_available
    assert defined?(WvRunner::WorkLoop)
  end

  def test_claude_code_is_available
    assert defined?(WvRunner::ClaudeCode)
  end

  def test_decider_is_available
    assert defined?(WvRunner::Decider)
  end

  def test_version_is_defined
    assert defined?(WvRunner::VERSION)
    assert_match(/^\d+\.\d+\.\d+$/, WvRunner::VERSION)
  end
end
