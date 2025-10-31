require "test_helper"

class DeciderTest < Minitest::Test
  def test_decider_responds_to_resolve
    decider = WvRunner::Decider.new
    assert_respond_to decider, :resolve
  end

  def test_resolve_returns_something
    decider = WvRunner::Decider.new
    result = decider.resolve
    # Currently returns nil, but method exists
    assert_nil result
  end
end
