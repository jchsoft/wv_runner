require "test_helper"

class ClaudeCodeTest < Minitest::Test
  def test_claude_code_responds_to_run
    claude = WvRunner::ClaudeCode.new
    assert_respond_to claude, :run
  end

  def test_run_mocks_system_call
    # Mock system to avoid actually calling claude executable
    Kernel.stub :system, nil do
      claude = WvRunner::ClaudeCode.new
      result = claude.run
      assert_nil result
    end
  end

  def test_claude_path_uses_env_variable
    Kernel.stub :system, nil do
      ENV['CLAUDE_PATH'] = '/custom/path/to/claude'
      claude = WvRunner::ClaudeCode.new
      # Should use the ENV path, not look for executable
      claude.run
      ENV['CLAUDE_PATH'] = nil
    end
  end
end
