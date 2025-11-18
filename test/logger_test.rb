require 'test_helper'
require 'stringio'

class LoggerTest < Minitest::Test
  def setup
    @log_output = StringIO.new
    @custom_logger = ::Logger.new(@log_output)
    WvRunner::Logger.logger = @custom_logger
  end

  def teardown
    WvRunner::Logger.logger = nil
  end

  def test_info_stdout_outputs_to_both_stdout_and_log
    assert_output("Test message\n") do
      WvRunner::Logger.info_stdout('Test message')
    end
    assert_includes @log_output.string, 'Test message'
    assert_includes @log_output.string, 'INFO'
  end

  def test_debug_only_goes_to_log
    assert_output('') do
      WvRunner::Logger.debug('Debug message')
    end
    assert_includes @log_output.string, 'Debug message'
    assert_includes @log_output.string, 'DEBUG'
  end

  def test_info_only_goes_to_log
    assert_output('') do
      WvRunner::Logger.info('Info message')
    end
    assert_includes @log_output.string, 'Info message'
    assert_includes @log_output.string, 'INFO'
  end

  def test_warn_outputs_to_both_with_emoji
    assert_output(/⚠️  Warning message/) do
      WvRunner::Logger.warn('Warning message')
    end
    assert_includes @log_output.string, 'Warning message'
    assert_includes @log_output.string, 'WARN'
  end

  def test_error_outputs_to_both_with_emoji
    assert_output(/❌ Error message/) do
      WvRunner::Logger.error('Error message')
    end
    assert_includes @log_output.string, 'Error message'
    assert_includes @log_output.string, 'ERROR'
  end

  def test_logger_creates_log_directory_and_file
    # Clean up first
    FileUtils.rm_rf('log') if Dir.exist?('log')

    # Create default logger (should create log directory)
    WvRunner::Logger.logger = nil
    WvRunner::Logger.logger

    assert Dir.exist?('log'), 'log directory should be created'
    assert File.exist?('log/wv_runner.log'), 'log file should be created'

    # Clean up
    FileUtils.rm_rf('log') if Dir.exist?('log')
  end

  def test_multiple_messages_accumulate_in_log
    3.times { |i| WvRunner::Logger.debug("Message #{i}") }
    log_content = @log_output.string
    assert_includes log_content, 'Message 0'
    assert_includes log_content, 'Message 1'
    assert_includes log_content, 'Message 2'
  end
end
