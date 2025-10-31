require "test_helper"

class WorkLoopTest < Minitest::Test
  def test_work_loop_responds_to_execute
    loop = WvRunner::WorkLoop.new
    assert_respond_to loop, :execute
  end

  def test_execute_with_once
    mock = Minitest::Mock.new
    mock.expect(:run, nil)
    WvRunner::ClaudeCode.stub :new, mock do
      loop = WvRunner::WorkLoop.new
      assert_output(/WorkLoop executing with mode: once/) { loop.execute(:once) }
      mock.verify
    end
  end

  def test_execute_with_today_exits_at_end_of_day
    call_count = 0
    mock = Minitest::Mock.new
    def mock.run
      true
    end

    WvRunner::ClaudeCode.stub :new, mock do
      loop = WvRunner::WorkLoop.new
      # Stub end_of_day? to return true immediately to prevent infinite loop
      def loop.end_of_day?
        true
      end
      assert_output(/Running task iteration/) { loop.execute(:today) }
    end
  end

  def test_execute_raises_on_invalid_how
    loop = WvRunner::WorkLoop.new
    assert_raises(ArgumentError) { loop.execute(:invalid) }
  end
end
