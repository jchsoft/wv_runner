require "wv_runner/version"
require "wv_runner/services/work_loop"
require "wv_runner/services/claude_code"
require "wv_runner/services/decider"
require "wv_runner/railtie"

module WvRunner
  class Error < StandardError; end

  def self.configure
    yield self if block_given?
  end
end
