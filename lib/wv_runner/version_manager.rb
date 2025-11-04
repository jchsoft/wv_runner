# frozen_string_literal: true

module WvRunner
  # VersionManager handles version incrementing by 0.1 increments
  # Reads and writes version from lib/wv_runner/version.rb
  class VersionManager
    VERSION_FILE = File.expand_path('../../wv_runner/version.rb', __dir__)

    def self.current_version
      WvRunner::VERSION
    end

    def self.increment_version!
      current = parse_version(current_version)
      new_version = increment_patch(current)
      write_version(new_version)
      puts "[VersionManager] Version incremented: #{current_version} → #{new_version}"
      new_version
    end

    private

    def self.parse_version(version_string)
      # Parse "0.1.0" into [0, 1, 0]
      version_string.split('.').map(&:to_i)
    end

    def self.increment_patch(version_array)
      # version_array is [major, minor, patch]
      # Increment patch by 1 to achieve 0.1 increments
      # e.g., [0, 1, 0] → [0, 1, 1], [0, 1, 9] → [0, 2, 0], [0, 9, 9] → [1, 0, 0]
      major, minor, patch = version_array

      patch += 1
      if patch >= 10
        minor += 1
        patch = 0
      end

      if minor >= 10
        major += 1
        minor = 0
      end

      "#{major}.#{minor}.#{patch}"
    end

    def self.write_version(new_version)
      version_content = <<~RUBY
        module WvRunner
          VERSION = "#{new_version}"
        end
      RUBY

      File.write(VERSION_FILE, version_content)

      # Reload the version constant
      Object.send(:remove_const, :WvRunner) if Object.const_defined?(:WvRunner)
      load(VERSION_FILE)
    end
  end
end
