require "test_helper"

class WorkLoopTest < Minitest::Test
  def test_work_loop_responds_to_execute
    loop = WvRunner::WorkLoop.new
    assert_respond_to loop, :execute
  end

  def test_execute_returns_something
    loop = WvRunner::WorkLoop.new
    result = loop.execute
    # Currently returns nil, but method exists
    assert_nil result
  end
end
