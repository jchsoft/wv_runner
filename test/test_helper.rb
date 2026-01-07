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
require "wv_runner"
