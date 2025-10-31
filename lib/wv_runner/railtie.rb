require 'rails'

module WvRunner
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/wv_runner.rake'
    end
  end
end