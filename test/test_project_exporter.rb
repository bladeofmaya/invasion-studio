require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestProjectExporter < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @sample_video = File.expand_path('test/samples/invasion-sample-720p.mp4')
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def create_clip(name)
    path = File.join(@tmp_dir, name)
    FileUtils.cp(@sample_video, path)
    path
  end

  def test_export_group_with_no_clips_raises
    project = InvasionExtractor::Project.new(@tmp_dir)
    exporter = InvasionExtractor::ProjectExporter.new(project, quiet: true)

    assert_raises(InvasionExtractor::Error) do
      exporter.export_group('Video 1')
    end
  end
end
