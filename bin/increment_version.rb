#!/usr/bin/env ruby
# frozen_string_literal: true

# Increment wv_runner version by 0.1
# This script is called by Claude Code after successfully completing a task
# Usage: ruby bin/increment_version.rb

# Add lib to load path
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'wv_runner/version_manager'

puts "[increment_version] Starting version increment..."
WvRunner::VersionManager.increment_version!
puts "[increment_version] Done!"
