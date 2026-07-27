require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestLocalDiskStorage < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @storage = InvasionStudio::Storage::LocalDiskStorage.new(@tmp_dir)
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_resolve_returns_absolute_path
    path = @storage.resolve('videos/clip.mp4')
    assert_equal File.join(@tmp_dir, 'videos/clip.mp4'), path
  end

  def test_resolve_rejects_paths_outside_root
    assert_nil @storage.resolve('../outside.mp4')
    assert_nil @storage.resolve('/tmp/outside.mp4')
  end

  def test_resolve_returns_nil_for_empty_key
    assert_nil @storage.resolve(nil)
    assert_nil @storage.resolve('')
  end

  def test_exist_checks_file_presence
    refute @storage.exist?('missing.mp4')

    File.write(File.join(@tmp_dir, 'present.mp4'), 'x')
    assert @storage.exist?('present.mp4')
  end

  def test_relative_path_strips_root_prefix
    absolute = File.join(@tmp_dir, 'videos/clip.mp4')
    assert_equal 'videos/clip.mp4', @storage.relative_path(absolute)
  end

  def test_relative_path_returns_key_as_is_for_relative_or_empty
    assert_nil @storage.relative_path(nil)
    assert_equal 'videos/clip.mp4', @storage.relative_path('videos/clip.mp4')
  end

  def test_store_copies_file_to_key
    source = File.join(@tmp_dir, 'source.mp4')
    File.write(source, 'video data')

    key = @storage.store(source, 'uploads/clip.mp4')
    assert_equal 'uploads/clip.mp4', key
    assert_equal 'video data', File.read(File.join(@tmp_dir, 'uploads/clip.mp4'))
    assert_equal 'video data', File.read(source)
  end

  def test_store_returns_nil_when_key_escapes_root
    source = File.join(@tmp_dir, 'source.mp4')
    File.write(source, 'x')

    assert_nil @storage.store(source, '../outside.mp4')
  end

  def test_move_renames_file_within_root
    source = File.join(@tmp_dir, 'old.mp4')
    File.write(source, 'video')

    key = @storage.move('old.mp4', 'new.mp4')
    assert_equal 'new.mp4', key
    assert_equal 'video', File.read(File.join(@tmp_dir, 'new.mp4'))
    refute File.exist?(source)
  end

  def test_move_returns_nil_for_missing_source
    assert_nil @storage.move('missing.mp4', 'new.mp4')
  end

  def test_move_returns_nil_when_destination_escapes_root
    source = File.join(@tmp_dir, 'old.mp4')
    File.write(source, 'x')

    assert_nil @storage.move('old.mp4', '../outside.mp4')
    assert File.exist?(source)
  end

  def test_delete_removes_file
    path = File.join(@tmp_dir, 'delete_me.mp4')
    File.write(path, 'x')

    assert @storage.delete('delete_me.mp4')
    refute File.exist?(path)
  end

  def test_delete_returns_false_for_missing_file
    refute @storage.delete('missing.mp4')
  end

  def test_delete_returns_false_for_escaping_key
    refute @storage.delete('../outside.mp4')
  end

  def test_url_returns_nil
    assert_nil @storage.url('anything.mp4')
  end
end

class TestStorageAdapter < Minitest::Test
  def setup
    @adapter = InvasionStudio::Storage::Adapter.new
  end

  def test_all_methods_raise_not_implemented
    assert_raises(InvasionStudio::Storage::Adapter::NotImplementedError) { @adapter.store('a', 'b') }
    assert_raises(InvasionStudio::Storage::Adapter::NotImplementedError) { @adapter.move('a', 'b') }
    assert_raises(InvasionStudio::Storage::Adapter::NotImplementedError) { @adapter.delete('a') }
    assert_raises(InvasionStudio::Storage::Adapter::NotImplementedError) { @adapter.resolve('a') }
    assert_raises(InvasionStudio::Storage::Adapter::NotImplementedError) { @adapter.exist?('a') }
    assert_raises(InvasionStudio::Storage::Adapter::NotImplementedError) { @adapter.relative_path('a') }
  end

  def test_url_returns_nil_by_default
    assert_nil @adapter.url('a')
  end
end
