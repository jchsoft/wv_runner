require 'rails'

module McptaskRunner
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/mcptask_runner.rake'
    end
  end
end
