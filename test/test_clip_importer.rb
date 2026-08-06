require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestClipImporter < Minitest::Test
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

  def create_project
    project = InvasionStudio::Project.new(@tmp_dir, database: @db, storage: @storage,
                                           clip_repository: @repository,
                                           group_repository: InvasionStudio::Database::GroupRepository.new(@db, clip_repository: @repository))
    project.delete_group('Video 1')
    project
  end

  def importer_for(project, metadata: {})
    probe = ->(_path) { metadata }
    InvasionStudio::ClipImporter.new(project, metadata_probe: probe)
  end

  def test_imports_uploaded_video_file
    project = create_project
    source = File.join(@tmp_dir, 'source.mp4')
    File.write(source, 'video data')
    tempfile = Tempfile.new(['upload', '.mp4'])
    FileUtils.cp(source, tempfile.path)

    importer = importer_for(project, metadata: { duration: 12.5, width: 1920, height: 1080, fps: 60 })
    clip = importer.import_upload(tempfile: tempfile, filename: 'my_clip.mp4')

    assert_equal 'clips/my_clip', clip['id']
    assert_equal 'my_clip.mp4', clip['filename']
    assert_equal 'uploaded', clip['source_kind']
    assert_in_delta 12.5, clip['duration']
    assert_equal 1920, clip['width']
    assert_equal File.size(tempfile.path), clip['filesize']
    assert File.exist?(File.join(@tmp_dir, 'clips', 'my_clip.mp4'))
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def test_rejects_unsupported_extension
    project = create_project
    tempfile = Tempfile.new(['upload', '.txt'])
    File.write(tempfile.path, 'text')
    importer = importer_for(project)

    error = assert_raises(InvasionStudio::Error) do
      importer.import_upload(tempfile: tempfile, filename: 'notes.txt')
    end
    assert_match(/Unsupported file type/, error.message)
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def test_rejects_file_that_is_not_a_readable_video
    project = create_project
    tempfile = Tempfile.new(['upload', '.mp4'])
    File.write(tempfile.path, 'not actually video data')
    importer = InvasionStudio::ClipImporter.new(project, metadata_probe: ->(_path) { nil })

    error = assert_raises(InvasionStudio::Error) do
      importer.import_upload(tempfile: tempfile, filename: 'fake.mp4')
    end
    assert_match(/not a readable video/i, error.message)
    refute File.exist?(File.join(@tmp_dir, 'clips', 'fake.mp4'))
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def test_rejects_file_when_probe_raises
    project = create_project
    tempfile = Tempfile.new(['upload', '.mp4'])
    File.write(tempfile.path, 'garbage')
    importer = InvasionStudio::ClipImporter.new(project, metadata_probe: ->(_path) { raise 'ffprobe exploded' })

    assert_raises(InvasionStudio::Error) do
      importer.import_upload(tempfile: tempfile, filename: 'garbage.mp4')
    end
    refute File.exist?(File.join(@tmp_dir, 'clips', 'garbage.mp4'))
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def test_rejects_empty_file
    project = create_project
    tempfile = Tempfile.new(['upload', '.mp4'])
    importer = importer_for(project)

    error = assert_raises(InvasionStudio::Error) do
      importer.import_upload(tempfile: tempfile, filename: 'empty.mp4')
    end
    assert_match(/empty/i, error.message)
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def test_rejects_file_exceeding_max_upload_size
    project = create_project
    tempfile = Tempfile.new(['upload', '.mp4'])
    File.write(tempfile.path, 'a' * 100)
    importer = InvasionStudio::ClipImporter.new(project, metadata_probe: ->(_path) { {} }, max_upload_bytes: 10)

    error = assert_raises(InvasionStudio::Error) do
      importer.import_upload(tempfile: tempfile, filename: 'big.mp4')
    end
    assert_match(/too large/i, error.message)
    refute File.exist?(File.join(@tmp_dir, 'clips', 'big.mp4'))
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def test_generates_unique_key_for_duplicate_filename
    project = create_project
    existing = File.join(@tmp_dir, 'clips')
    FileUtils.mkdir_p(existing)
    File.write(File.join(existing, 'my_clip.mp4'), 'existing')
    @repository.create(
      'id' => 'clips/my_clip', 'filename' => 'my_clip.mp4', 'path' => 'clips/my_clip.mp4', 'source_kind' => 'uploaded'
    )

    source = File.join(@tmp_dir, 'source.mp4')
    File.write(source, 'video data')
    tempfile = Tempfile.new(['upload', '.mp4'])
    FileUtils.cp(source, tempfile.path)

    importer = importer_for(project)
    clip = importer.import_upload(tempfile: tempfile, filename: 'my_clip.mp4')

    assert_equal 'clips/my_clip_1', clip['id']
    assert File.exist?(File.join(@tmp_dir, 'clips', 'my_clip_1.mp4'))
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def test_sanitizes_filename_for_storage_key
    project = create_project
    source = File.join(@tmp_dir, 'source.mp4')
    File.write(source, 'video data')
    tempfile = Tempfile.new(['upload', '.mp4'])
    FileUtils.cp(source, tempfile.path)

    importer = importer_for(project)
    clip = importer.import_upload(tempfile: tempfile, filename: 'my clip with spaces & stuff.mp4')

    assert_equal 'clips/my_clip_with_spaces___stuff', clip['id']
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def test_promotes_row_created_by_folder_scan_during_upload
    project = create_project
    tempfile = Tempfile.new(['upload', '.mp4'])
    File.write(tempfile.path, 'video data')
    scanning_storage = Class.new(InvasionStudio::Storage::LocalDiskStorage) do
      attr_accessor :after_store

      def store(source_path, key)
        result = super
        callback, self.after_store = after_store, nil
        callback&.call
        result
      end
    end.new(@tmp_dir)
    scanning_storage.after_store = -> { project.sync_clips! }
    importer = InvasionStudio::ClipImporter.new(
      project, storage: scanning_storage, metadata_probe: ->(_path) { { duration: 12.5 } }
    )

    clip = importer.import_upload(tempfile: tempfile, filename: 'race.mp4')
    rows = @db[:clips].where(storage_path: 'clips/race.mp4').all

    assert_equal 1, rows.length
    assert_equal clip['id'], rows.first[:id]
    assert_equal 'uploaded', rows.first[:source_kind]
    assert_in_delta 12.5, rows.first[:duration]
  ensure
    tempfile&.close
    tempfile&.unlink
  end
end
