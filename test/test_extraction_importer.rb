require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestExtractionImporter < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@tmp_dir, 'clips'))
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_records_extracted_clips_with_provenance
    clip_path = File.join(@tmp_dir, 'clips', 'clip_00001.mp4')
    File.write(clip_path, 'video')

    project = InvasionStudio::Project.new(@tmp_dir)
    importer = InvasionStudio::ExtractionImporter.new(@tmp_dir, project: project)
    recorded = importer.record([{ path: clip_path, source: '/recordings/session-01.mp4' }])

    assert_equal 1, recorded
    clip = project.clip_repository.find('clip_00001')
    assert_equal 'extracted', clip['source_kind']
    assert_equal 'session-01.mp4', clip['source_video']
  end

  def test_ignores_unknown_paths_and_empty_lists
    project = InvasionStudio::Project.new(@tmp_dir)
    importer = InvasionStudio::ExtractionImporter.new(@tmp_dir, project: project)

    assert_equal 0, importer.record([])
    assert_equal 0, importer.record([{ path: File.join(@tmp_dir, 'clips', 'nope.mp4'), source: 'x.mp4' }])
  end

  def test_records_files_created_after_the_project_was_opened
    project = InvasionStudio::Project.new(@tmp_dir)
    importer = InvasionStudio::ExtractionImporter.new(@tmp_dir, project: project)

    # Simulates extraction: the file appears after the initial folder scan.
    clip_path = File.join(@tmp_dir, 'clips', 'clip_00001.mp4')
    File.write(clip_path, 'video')

    assert_equal 1, importer.record([{ path: clip_path, source: 'rec.mp4' }])
    assert_equal 'extracted', project.clip_repository.find('clip_00001')['source_kind']
  end

  def test_highest_clip_number_includes_trashed_clips
    project = InvasionStudio::Project.new(@tmp_dir)
    File.write(File.join(@tmp_dir, 'clips', 'clip_00003.mp4'), 'video')
    project.sync_clips!
    trashed = project.clip_repository.find('clip_00003')
    FileUtils.mkdir_p(File.join(@tmp_dir, '.trashed'))
    FileUtils.mv(File.join(@tmp_dir, 'clips', 'clip_00003.mp4'), File.join(@tmp_dir, '.trashed', 'clip_00003.mp4'))
    project.clip_repository.mark_deleted(trashed['id'], deleted_path: '.trashed/clip_00003.mp4')

    importer = InvasionStudio::ExtractionImporter.new(@tmp_dir, project: project)

    assert_equal 3, importer.highest_clip_number
  end

  def test_never_stamps_a_trashed_clip
    project = InvasionStudio::Project.new(@tmp_dir)
    File.write(File.join(@tmp_dir, 'clips', 'clip_00001.mp4'), 'old')
    project.sync_clips!
    project.clip_repository.mark_deleted('clip_00001', deleted_path: '.trashed/clip_00001.mp4')
    FileUtils.mkdir_p(File.join(@tmp_dir, '.trashed'))
    FileUtils.mv(File.join(@tmp_dir, 'clips', 'clip_00001.mp4'), File.join(@tmp_dir, '.trashed', 'clip_00001.mp4'))

    # A colliding file should never be produced with correct numbering, but
    # even if it is, the trashed record must not be relabeled.
    collision = File.join(@tmp_dir, 'clips', 'clip_00001.mp4')
    File.write(collision, 'new')
    importer = InvasionStudio::ExtractionImporter.new(@tmp_dir, project: project)

    assert_equal 0, importer.record([{ path: collision, source: 'rec.mp4' }])
    assert_equal 'external', project.clip_repository.find('clip_00001')['source_kind']
  end
end
