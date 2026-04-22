# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'json'
require 'fileutils'

class PermissionSyncerTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir('permission_syncer_test')
    @baseline_path = File.join(@tmpdir, 'baseline.json')
    @target_dir = File.join(@tmpdir, 'project')
    FileUtils.mkdir_p(@target_dir)

    File.write(@baseline_path, JSON.generate(
      'permissions' => { 'allow' => ['Bash(git:*)', 'Bash(rails:*)', 'mcp__foo__*'], 'deny' => [] },
      'enableAllProjectMcpServers' => true,
      'enabledMcpjsonServers' => %w[foo bar]
    ))
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
  end

  def target_path
    File.join(@target_dir, '.claude', 'settings.local.json')
  end

  def test_creates_target_when_missing
    syncer = McptaskRunner::PermissionSyncer.sync(target_dir: @target_dir, baseline_path: @baseline_path)
    result = JSON.parse(File.read(target_path))

    assert_equal %w[Bash(git:*) Bash(rails:*) mcp__foo__*], result['permissions']['allow']
    assert_equal true, result['enableAllProjectMcpServers']
    assert_equal %w[foo bar], result['enabledMcpjsonServers']
    assert_equal 3, syncer.added_permissions.size
    assert_equal %w[foo bar], syncer.added_servers
    assert syncer.flipped_enable_all
  end

  def test_merges_into_existing_target_preserves_extras
    FileUtils.mkdir_p(File.dirname(target_path))
    File.write(target_path, JSON.generate(
      'permissions' => { 'allow' => ['Bash(git:*)', 'Bash(my-custom:*)'], 'deny' => [] },
      'enabledMcpjsonServers' => ['foo', 'custom-server'],
      'spinnerTipsEnabled' => true
    ))

    syncer = McptaskRunner::PermissionSyncer.sync(target_dir: @target_dir, baseline_path: @baseline_path)
    result = JSON.parse(File.read(target_path))

    assert_equal ['Bash(git:*)', 'Bash(my-custom:*)', 'Bash(rails:*)', 'mcp__foo__*'], result['permissions']['allow']
    assert_equal ['foo', 'custom-server', 'bar'], result['enabledMcpjsonServers']
    assert_equal true, result['enableAllProjectMcpServers']
    assert_equal true, result['spinnerTipsEnabled']
    assert_equal ['Bash(rails:*)', 'mcp__foo__*'], syncer.added_permissions
    assert_equal ['bar'], syncer.added_servers
    assert syncer.flipped_enable_all
  end

  def test_no_changes_when_already_in_sync
    FileUtils.mkdir_p(File.dirname(target_path))
    File.write(target_path, JSON.generate(
      'permissions' => { 'allow' => ['Bash(git:*)', 'Bash(rails:*)', 'mcp__foo__*'], 'deny' => [] },
      'enabledMcpjsonServers' => %w[foo bar],
      'enableAllProjectMcpServers' => true
    ))

    syncer = McptaskRunner::PermissionSyncer.sync(target_dir: @target_dir, baseline_path: @baseline_path)

    assert_empty syncer.added_permissions
    assert_empty syncer.added_servers
    refute syncer.flipped_enable_all
    assert_match(/No changes needed/, syncer.report)
  end

  def test_invalid_json_target_raises
    FileUtils.mkdir_p(File.dirname(target_path))
    File.write(target_path, '{ this is not json')

    assert_raises(RuntimeError) do
      McptaskRunner::PermissionSyncer.sync(target_dir: @target_dir, baseline_path: @baseline_path)
    end
  end

  def test_missing_baseline_raises
    assert_raises(RuntimeError) do
      McptaskRunner::PermissionSyncer.sync(target_dir: @target_dir, baseline_path: '/nonexistent/baseline.json')
    end
  end

  def test_ships_with_gem
    path = File.expand_path('../../config/baseline_permissions.json', __dir__)
    assert File.exist?(path), "Shipped baseline missing at #{path}"
    data = JSON.parse(File.read(path))
    assert data['permissions']['allow'].is_a?(Array)
  end
end
