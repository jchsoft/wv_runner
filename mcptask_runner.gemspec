require_relative "lib/mcptask_runner/version"

Gem::Specification.new do |spec|
  spec.name          = "mcptask_runner"
  spec.version       = McptaskRunner::VERSION
  spec.authors       = ["Josef Chmel"]
  spec.email         = ["info@jchsoft.cz"]
  spec.summary       = "Claude Code automation gem for mcptask.online task execution"
  spec.description   = "Adds rake tasks to Rails app for automated Claude Code execution"
  spec.homepage      = "https://github.com/jchsoft/mcptask_runner"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir.glob("lib/**/*") + Dir.glob("config/**/*")
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "rails", ">= 6.0"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-mock", "~> 1.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "rubocop-rails-omakase", "~> 1.0"
  spec.add_development_dependency "reek", "~> 6.0"
  spec.add_development_dependency "flay", "~> 2.0"
end
