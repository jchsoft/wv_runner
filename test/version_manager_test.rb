require "test_helper"

class VersionManagerTest < Minitest::Test
  def test_current_version_returns_version_constant
    version = WvRunner::VersionManager.current_version
    assert version.is_a?(String)
    assert_match(/^\d+\.\d+\.\d+$/, version)
  end

  def test_increment_version_increments_patch
    # This is a destructive test, so we need to be careful
    # We'll test the parsing logic instead
    initial = "0.1.0"
    incremented = WvRunner::VersionManager.send(:increment_patch, [0, 1, 0])
    assert_equal "0.1.1", incremented
  end

  def test_increment_patch_wraps_at_10
    # 0.1.9 should become 0.2.0
    incremented = WvRunner::VersionManager.send(:increment_patch, [0, 1, 9])
    assert_equal "0.2.0", incremented
  end

  def test_increment_patch_wraps_minor
    # 0.9.9 should become 1.0.0
    incremented = WvRunner::VersionManager.send(:increment_patch, [0, 9, 9])
    assert_equal "1.0.0", incremented
  end

  def test_parse_version_parses_semver
    parsed = WvRunner::VersionManager.send(:parse_version, "1.2.3")
    assert_equal [1, 2, 3], parsed
  end
end
