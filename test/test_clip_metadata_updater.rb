require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestClipMetadataUpdater < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db = InvasionStudio::Database.migrate_to_current!(@tmp_dir)
    @storage = InvasionStudio::Storage::LocalDiskStorage.new(@tmp_dir)
    @repository = InvasionStudio::Database::ClipRepository.new(@db, @storage)
    @project = InvasionStudio::Project.new(
      @tmp_dir,
      database: @db,
      storage: @storage,
      clip_repository: @repository,
      group_repository: InvasionStudio::Database::GroupRepository.new(@db, clip_repository: @repository)
    )
  end

  def teardown
    @db.disconnect
    FileUtils.rm_rf(@tmp_dir)
  end

  def create_clip(id, path: "#{id}.mp4")
    File.write(File.join(@tmp_dir, path), 'video bytes')
    @repository.create(
      'id' => id,
      'filename' => File.basename(path),
      'path' => path,
      'source_kind' => 'external'
    )
  end

  def updater(metadata)
    InvasionStudio::ClipMetadataUpdater.new(@project, metadata_probe: ->(_path) { metadata })
  end

  def test_update_stores_probed_metadata_and_filesize
    create_clip('a')

    result = updater(
      duration: 42.5, width: 1920, height: 1080, fps: 60.0,
      video_codec: 'h264', audio_codec: 'aac'
    ).update('a')

    clip = @repository.find('a')
    assert_equal 42.5, clip['duration']
    assert_equal 1920, clip['width']
    assert_equal 1080, clip['height']
    assert_equal 60.0, clip['fps']
    assert_equal 'h264', clip['video_codec']
    assert_equal 'aac', clip['audio_codec']
    assert_equal File.size(File.join(@tmp_dir, 'a.mp4')), clip['filesize']
    assert_equal clip['duration'], result['duration']
  end

  def test_update_returns_false_for_unknown_clip
    refute updater(duration: 1.0).update('missing')
  end

  def test_update_returns_false_when_file_is_gone
    create_clip('a')
    FileUtils.rm_f(File.join(@tmp_dir, 'a.mp4'))

    refute updater(duration: 1.0).update('a')
  end

  def test_update_returns_false_when_probe_fails
    create_clip('a')
    failing = InvasionStudio::ClipMetadataUpdater.new(@project, metadata_probe: ->(_path) { raise 'boom' })

    refute failing.update('a')
    assert_nil @repository.find('a')['duration']
  end
end
