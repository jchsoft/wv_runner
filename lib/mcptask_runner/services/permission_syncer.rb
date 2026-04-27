# frozen_string_literal: true

require 'json'
require 'fileutils'

module McptaskRunner
  # Merges a baseline permissions file (shipped with mcptask_runner) into a
  # target project's .claude/settings.local.json so that spawned Claude Code
  # runs have all required auto-approvals and MCP servers enabled.
  #
  # Merge rules:
  #   - permissions.allow        → union (dedupe, preserve target extras)
  #   - permissions.deny         → union (dedupe, preserve target extras)
  #   - enabledMcpjsonServers    → union (dedupe, preserve target extras)
  #   - enableAllProjectMcpServers → OR (baseline || target)
  #   - any other existing keys in target are preserved untouched
  class PermissionSyncer
    BASELINE_FILE = File.expand_path('../../../config/baseline_permissions.json', __dir__)
    TARGET_RELATIVE_PATH = '.claude/settings.local.json'

    attr_reader :target_dir, :baseline_path, :added_permissions, :added_servers, :flipped_enable_all

    def initialize(target_dir: Dir.pwd, baseline_path: BASELINE_FILE)
      @target_dir = File.expand_path(target_dir)
      @baseline_path = baseline_path
      @added_permissions = []
      @added_servers = []
      @flipped_enable_all = false
    end

    def self.sync(target_dir: Dir.pwd, baseline_path: BASELINE_FILE)
      new(target_dir: target_dir, baseline_path: baseline_path).sync
    end

    def sync
      raise "Baseline file not found: #{baseline_path}" unless File.exist?(baseline_path)

      @baseline = JSON.parse(File.read(baseline_path))
      @target = load_or_init_target

      merge_permissions
      merge_mcp_servers
      merge_enable_all

      write_target
      self
    end

    def target_path
      File.join(target_dir, TARGET_RELATIVE_PATH)
    end

    def report
      return 'No changes needed — target already in sync with baseline.' if no_changes?

      lines = ["Updated: #{target_path}"]
      lines << "  + #{added_permissions.size} permission(s)" if added_permissions.any?
      added_permissions.each { |p| lines << "      • #{p}" }
      lines << "  + #{added_servers.size} MCP server(s)" if added_servers.any?
      added_servers.each { |s| lines << "      • #{s}" }
      lines << "  • enableAllProjectMcpServers flipped to true" if flipped_enable_all
      lines.join("\n")
    end

    private

    def no_changes?
      added_permissions.empty? && added_servers.empty? && !flipped_enable_all
    end

    def load_or_init_target
      return default_target_structure unless File.exist?(target_path)

      JSON.parse(File.read(target_path))
    rescue JSON::ParserError => e
      raise "Target file #{target_path} is not valid JSON: #{e.message}"
    end

    def default_target_structure
      { 'permissions' => { 'allow' => [], 'deny' => [] }, 'enabledMcpjsonServers' => [] }
    end

    def merge_permissions
      @target['permissions'] ||= { 'allow' => [], 'deny' => [] }
      %w[allow deny].each do |key|
        @target['permissions'][key] ||= []
        new_entries = (@baseline.dig('permissions', key) || []) - @target['permissions'][key]
        @target['permissions'][key].concat(new_entries)
        @added_permissions.concat(new_entries) if key == 'allow'
      end
    end

    def merge_mcp_servers
      @target['enabledMcpjsonServers'] ||= []
      new_servers = (@baseline['enabledMcpjsonServers'] || []) - @target['enabledMcpjsonServers']
      @target['enabledMcpjsonServers'].concat(new_servers)
      @added_servers = new_servers
    end

    def merge_enable_all
      return unless @baseline['enableAllProjectMcpServers'] == true
      return if @target['enableAllProjectMcpServers'] == true

      @target['enableAllProjectMcpServers'] = true
      @flipped_enable_all = true
    end

    def write_target
      FileUtils.mkdir_p(File.dirname(target_path))
      File.write(target_path, "#{JSON.pretty_generate(@target)}\n")
    end
  end
end
