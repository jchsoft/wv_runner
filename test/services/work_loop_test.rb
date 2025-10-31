require "test_helper"

class WorkLoopTest < Minitest::Test
  def test_work_loop_responds_to_execute
    loop = WvRunner::WorkLoop.new
    assert_respond_to loop, :execute
  end

  def test_execute_with_once
    loop = WvRunner::WorkLoop.new
    assert_output(/WorkLoop executing with mode: once/) { loop.execute(:once) }
  end

  def test_execute_with_today
    loop = WvRunner::WorkLoop.new
    assert_output(/WorkLoop executing with mode: today/) { loop.execute(:today) }
  end

  def test_execute_with_daily
    loop = WvRunner::WorkLoop.new
    assert_output(/WorkLoop executing with mode: daily/) { loop.execute(:daily) }
  end

  def test_execute_raises_on_invalid_how
    loop = WvRunner::WorkLoop.new
    assert_raises(ArgumentError) { loop.execute(:invalid) }
  end
end
