require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestStorageStatistics < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @cache_dir = Dir.mktmpdir
    File.write(File.join(@tmp_dir, 'clip1.mp4'), 'a' * 100)
    File.write(File.join(@tmp_dir, 'clip2.mp4'), 'b' * 50)
    @project = InvasionStudio::Project.new(@tmp_dir)
    @project.clip_repository.update('clip1', 'duration' => 90.0)
    @project.clip_repository.update('clip2', 'duration' => 30.0)

    FileUtils.mkdir_p(File.join(@tmp_dir, 'thumbnails'))
    File.write(File.join(@tmp_dir, 'thumbnails', 'clip1.jpg'), 'c' * 10)
    FileUtils.mkdir_p(File.join(@tmp_dir, 'exports'))
    File.write(File.join(@tmp_dir, 'exports', 'combined.mp4'), 'd' * 200)
    FileUtils.mkdir_p(File.join(@tmp_dir, '.trashed'))
    File.write(File.join(@tmp_dir, '.trashed', 'old.mp4'), 'e' * 40)
    File.write(File.join(@cache_dir, 'ocr.yml'), 'f' * 30)

    @statistics = InvasionStudio::Webui::StorageStatistics.new(@project, cache_dirs: { preview: File.join(@tmp_dir, '.preview_cache'), ocr: @cache_dir })
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
    FileUtils.rm_rf(@cache_dir)
  end

  def test_call_reports_per_category_counts_and_bytes
    stats = @statistics.call
    assert_equal @project.folder_path, stats['project_path']

    assert_equal 2, stats['clips']['count']
    assert_equal 150, stats['clips']['bytes']
    assert_in_delta 120.0, stats['clips']['duration_seconds']
    assert_equal({ 'count' => 1, 'bytes' => 10 }, stats['thumbnails'])
    assert_equal({ 'count' => 1, 'bytes' => 200 }, stats['exports'])
    assert_equal({ 'count' => 1, 'bytes' => 40 }, stats['trash'])
    assert_equal({ 'count' => 1, 'bytes' => 30 }, stats['cache'])
    assert stats['database']['bytes'].positive?
    expected_total = 150 + 10 + 200 + 40 + 30 + stats['database']['bytes']
    assert_equal expected_total, stats['total_bytes']
  end

  def test_clear_cache_removes_files_and_reports_freed_bytes
    freed = @statistics.clear_cache!(scope: 'ocr')

    assert_equal 30, freed
    assert_empty Dir.children(@cache_dir)
    assert_equal 0, @statistics.call['cache']['bytes']
  end

  def test_cache_scopes_are_reported_and_cleared_independently
    preview = File.join(@tmp_dir, '.preview_cache')
    FileUtils.mkdir_p(preview)
    File.write(File.join(preview, 'preview.mp4'), 'preview')
    stats = @statistics.call
    assert_equal 7, stats['preview_cache']['bytes']
    assert_equal 30, stats['ocr_cache']['bytes']
    assert_equal preview, stats['preview_cache']['path']
    assert_equal @cache_dir, stats['ocr_cache']['path']
    assert_raises(InvasionStudio::Error) { @statistics.clear_cache!(scope: '../') }
    assert_equal 7, @statistics.clear_cache!(scope: 'preview')
    assert File.exist?(File.join(@cache_dir, 'ocr.yml'))
    assert_equal 30, @statistics.clear_cache!(scope: 'ocr')
  end

  def test_missing_directories_count_as_zero
    FileUtils.rm_rf(File.join(@tmp_dir, 'exports'))
    stats = @statistics.call

    assert_equal({ 'count' => 0, 'bytes' => 0 }, stats['exports'])
  end

  def test_does_not_clear_through_a_symlinked_cache_root
    File.symlink(@cache_dir, File.join(@tmp_dir, '.preview_cache'))
    assert_raises(InvasionStudio::Error) { @statistics.clear_cache!(scope: 'preview') }
    assert File.exist?(File.join(@cache_dir, 'ocr.yml'))
  end
end
