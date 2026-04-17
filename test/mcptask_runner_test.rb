require "test_helper"

class McptaskRunnerTest < Minitest::Test
  def test_module_exists
    assert defined?(McptaskRunner)
  end

  def test_error_inherits_from_standard_error
    assert McptaskRunner::Error < StandardError
  end

  def test_can_raise_mcptask_runner_error
    assert_raises(McptaskRunner::Error) do
      raise McptaskRunner::Error, "Test error"
    end
  end

  def test_work_loop_is_available
    assert defined?(McptaskRunner::WorkLoop)
  end

  def test_claude_code_is_available
    assert defined?(McptaskRunner::ClaudeCode)
  end

  def test_decider_is_available
    assert defined?(McptaskRunner::Decider)
  end

  def test_version_is_defined
    assert defined?(McptaskRunner::VERSION)
    assert_match(/^\d+\.\d+\.\d+$/, McptaskRunner::VERSION)
  end
end
