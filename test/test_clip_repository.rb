require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestClipRepository < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db = InvasionStudio::Database.migrate_to_current!(@tmp_dir)
    @storage = InvasionStudio::Storage::LocalDiskStorage.new(@tmp_dir)
    @repository = InvasionStudio::Database::ClipRepository.new(@db, @storage)
  end

  def teardown
    @db.disconnect
    FileUtils.rm_rf(@tmp_dir)
  end

  def create_clip_file(name)
    path = File.join(@tmp_dir, name)
    File.write(path, 'dummy')
    path
  end

  def create_clip(name, attributes = {})
    create_clip_file(name)
    defaults = {
      'id' => File.basename(name, '.*'),
      'filename' => name,
      'path' => name,
      'title' => nil,
      'note' => '',
      'rating' => 0,
      'result' => nil,
      'source_kind' => 'external'
    }
    @repository.create(defaults.merge(attributes))
  end

  def test_update_accepts_media_metadata_fields
    create_clip('clip1.mp4')

    assert @repository.update('clip1',
                              'duration' => 12.5, 'filesize' => 1024, 'width' => 1920, 'height' => 1080,
                              'fps' => 59.94, 'video_codec' => 'h264', 'audio_codec' => 'aac')

    clip = @repository.find('clip1')
    assert_equal 12.5, clip['duration']
    assert_equal 1024, clip['filesize']
    assert_equal 1920, clip['width']
    assert_equal 1080, clip['height']
    assert_equal 59.94, clip['fps']
    assert_equal 'h264', clip['video_codec']
    assert_equal 'aac', clip['audio_codec']
  end

  def test_create_and_find_clip
    clip = create_clip('clip1.mp4', 'title' => 'First clip')

    found = @repository.find('clip1')
    assert_equal 'clip1', found['id']
    assert_equal 'First clip', found['title']
    assert_equal 'clip1.mp4', found['filename']
    assert_equal [], found['cuts']
    refute found['deleted']
  end

  def test_active_excludes_deleted_clips
    create_clip('a.mp4')
    clip = create_clip('b.mp4')
    @repository.mark_deleted('b', deleted_path: '.trashed/b.mp4')

    assert_equal ['a'], @repository.active.map { |c| c['id'] }
  end

  def test_deleted_returns_only_deleted_clips
    create_clip('a.mp4')
    create_clip('b.mp4')
    @repository.mark_deleted('b', deleted_path: '.trashed/b.mp4')

    assert_equal ['b'], @repository.deleted.map { |c| c['id'] }
  end

  def test_update_modifies_fields
    create_clip('clip1.mp4')

    assert @repository.update('clip1', 'title' => 'Updated', 'rating' => 4)
    clip = @repository.find('clip1')
    assert_equal 'Updated', clip['title']
    assert_equal 4, clip['rating']
  end

  def test_update_normalizes_title_to_nil_when_blank
    create_clip('clip1.mp4', 'title' => 'Old')

    @repository.update('clip1', 'title' => '   ')
    assert_nil @repository.find('clip1')['title']
  end

  def test_update_normalizes_result_to_nil_when_invalid
    create_clip('clip1.mp4')

    @repository.update('clip1', 'result' => 'invalid')
    assert_nil @repository.find('clip1')['result']
  end

  def test_update_clamps_rating
    create_clip('clip1.mp4')

    @repository.update('clip1', 'rating' => 10)
    assert_equal 5, @repository.find('clip1')['rating']

    @repository.update('clip1', 'rating' => -3)
    assert_equal 0, @repository.find('clip1')['rating']
  end

  def test_update_cuts_normalizes_and_merges
    create_clip('clip1.mp4')

    assert @repository.update_cuts('clip1', [
      { 'start' => 4.0, 'end' => 8.0 },
      { 'start' => 1.0, 'end' => 5.0 }
    ])
    assert_equal [{ 'start' => 1.0, 'end' => 8.0 }], @repository.find('clip1')['cuts']
  end

  def test_update_cuts_rejects_invalid_cuts
    create_clip('clip1.mp4')

    refute @repository.update_cuts('clip1', [{ 'start' => -1, 'end' => 2 }])
    refute @repository.update_cuts('clip1', 'not-an-array')
  end

  def test_mark_deleted_and_restored
    create_clip('clip1.mp4')

    @repository.mark_deleted('clip1', deleted_path: '.trashed/clip1.mp4')
    assert @repository.find('clip1')['deleted']

    @repository.mark_restored('clip1')
    refute @repository.find('clip1')['deleted']
    assert_nil @repository.find('clip1')['trash_path']
  end

  def test_remove_missing_deletes_clips_without_files
    create_clip('present.mp4')
    create_clip('missing.mp4')
    File.delete(File.join(@tmp_dir, 'missing.mp4'))

    removed = @repository.remove_missing
    assert_equal 1, removed
    assert_equal ['present'], @repository.all.map { |c| c['id'] }
  end

  def test_resolve_rejects_paths_outside_project
    create_clip('clip1.mp4')

    assert_nil @repository.resolve('../outside.mp4')
    assert_nil @repository.resolve('/tmp/outside.mp4')
  end

  def test_relative_path_returns_relative_value
    create_clip('clip1.mp4')

    assert_equal 'clip1.mp4', @repository.relative_path(File.join(@tmp_dir, 'clip1.mp4'))
  end

  def test_path_for_uses_clip_path
    create_clip('clip1.mp4')
    clip = @repository.find('clip1')

    assert_equal File.join(@tmp_dir, 'clip1.mp4'), @repository.path_for(clip)
  end

  def test_tags_for_clip
    create_clip('clip1.mp4')
    tag_id = @db[:tags].insert(name: 'pvp', created_at: Time.now.utc.iso8601)
    @repository.add_tag('clip1', tag_id)

    assert_equal ['pvp'], @repository.tags_for('clip1')
  end
end
