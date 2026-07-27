require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestThumbnailJob < Minitest::Test
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
    @project.delete_group('Video 1')
  end

  def teardown
    @db.disconnect
    FileUtils.rm_rf(@tmp_dir)
  end

  def create_clip(id, filename: nil, path: id)
    full_path = File.join(@tmp_dir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, 'video')
    @repository.create(
      'id' => id,
      'filename' => filename || File.basename(path),
      'path' => path,
      'source_kind' => 'external'
    )
  end

  def test_perform_async_is_available
    job = InvasionStudio::Workers::ThumbnailJob
    assert_respond_to job, :perform_async
  end

  def test_job_class_includes_sucker_punch
    assert_includes InvasionStudio::Workers::ThumbnailJob.included_modules, SuckerPunch::Job
  end

  def test_metadata_job_is_available
    job = InvasionStudio::Workers::MetadataJob
    assert_respond_to job, :perform_async
    assert_includes job.included_modules, SuckerPunch::Job
  end
end
