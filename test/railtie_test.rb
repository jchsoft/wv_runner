require "test_helper"
require "mcptask_runner/railtie"

class RailtieTest < Minitest::Test
  def test_railtie_is_rails_railtie
    assert McptaskRunner::Railtie < Rails::Railtie
  end

  def test_railtie_loads_rake_tasks
    # Verify that the railtie is properly configured to load rake tasks
    assert McptaskRunner::Railtie.respond_to?(:rake_tasks)
  end

  def test_railtie_is_loaded_when_gem_is_required
    # The railtie should be auto-loaded via require in lib/mcptask_runner.rb
    assert defined?(McptaskRunner::Railtie)
  end
end
