require 'logger'
require 'fileutils'

module WvRunner
  module Logger
    class << self
      attr_writer :logger

      def logger
        @logger ||= create_default_logger
      end

      # Output to both stdout and log file (for user-facing messages)
      def info_stdout(message)
        puts message
        logger.info(message)
      end

      # Output to log file only (for debug/internal messages)
      def debug(message)
        logger.debug(message)
      end

      def info(message)
        logger.info(message)
      end

      def warn(message)
        puts "⚠️  #{message}"
        logger.warn(message)
      end

      def error(message)
        puts "❌ #{message}"
        logger.error(message)
      end

      private

      def create_default_logger
        log_dir = 'log'
        FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)

        log_file = File.join(log_dir, 'wv_runner.log')
        file_logger = ::Logger.new(log_file, 'daily')
        file_logger.level = ::Logger::DEBUG
        file_logger.formatter = proc do |severity, datetime, progname, msg|
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity.ljust(5)} - #{msg}\n"
        end
        file_logger
      end
    end
  end
end
