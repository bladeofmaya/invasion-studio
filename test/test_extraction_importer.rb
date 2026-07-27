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
end
