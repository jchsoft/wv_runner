require_relative "lib/wv_runner/version"

Gem::Specification.new do |spec|
  spec.name          = "wv_runner"
  spec.version       = WvRunner::VERSION
  spec.authors       = ["Josef Chmel"]
  spec.email         = ["info@jchsoft.cz"]
  spec.summary       = "Claude Code automation gem for WorkVector task execution"
  spec.description   = "Adds rake tasks to Rails app for automated Claude Code execution"
  spec.homepage      = "https://github.com/jchsoft/wv_runner"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir.glob("lib/**/*")
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "rails", ">= 6.0"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-mock", "~> 1.0"
end
