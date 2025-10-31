require "test_helper"

class ClaudeCodeTest < Minitest::Test
  def test_claude_code_responds_to_run
    claude = WvRunner::ClaudeCode.new
    assert_respond_to claude, :run
  end

  def test_run_returns_something
    claude = WvRunner::ClaudeCode.new
    result = claude.run
    # Currently returns nil, but method exists
    assert_nil result
  end
end
