require "minitest/autorun"
begin
  require "minitest/mock"
rescue LoadError
  gem "minitest-mock"
  require "minitest/mock"
end
require "active_support"
require "active_support/core_ext/time"
require "active_support/core_ext/numeric/time"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "mcptask_runner"

# Prevent tests from accidentally opening a real WebSocket to mcptask.online when the
# developer shell has MCPTASK_TOKEN exported. Real emits require an explicit start_session.
ENV.delete("MCPT_RUNNER_CABLE_URL")
ENV.delete("MCPTASK_TOKEN")
