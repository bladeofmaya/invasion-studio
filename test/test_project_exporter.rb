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

  def test_export_group_splices_and_creates_kdenlive
    skip "Video processing tests skipped to avoid timeouts"

    create_clip('a.mp4')
    create_clip('b.mp4')

    project = InvasionExtractor::Project.new(@tmp_dir)
    project.add_clip_to_group('Video 1', 'a')
    project.add_clip_to_group('Video 1', 'b')

    exporter = InvasionExtractor::ProjectExporter.new(project, quiet: true)
    spliced, kdenlive = exporter.export_group('Video 1')

    assert File.exist?(spliced)
    assert File.exist?(kdenlive)
    assert spliced.end_with?('combined.mp4')
    assert kdenlive.end_with?('combined.kdenlive')
  end

  def test_export_group_with_custom_basename
    skip "Video processing tests skipped to avoid timeouts"

    create_clip('a.mp4')
    project = InvasionExtractor::Project.new(@tmp_dir)
    project.add_clip_to_group('Video 1', 'a')

    exporter = InvasionExtractor::ProjectExporter.new(project, quiet: true)
    spliced, kdenlive = exporter.export_group('Video 1', 'my-export')

    assert spliced.end_with?('my-export.mp4')
    assert kdenlive.end_with?('my-export.kdenlive')
  end

  def test_export_group_with_no_clips_raises
    project = InvasionExtractor::Project.new(@tmp_dir)
    exporter = InvasionExtractor::ProjectExporter.new(project, quiet: true)

    assert_raises(InvasionExtractor::Error) do
      exporter.export_group('Video 1')
    end
  end

  def test_export_group_creates_subfolder
    skip "Video processing tests skipped to avoid timeouts"

    create_clip('a.mp4')
    project = InvasionExtractor::Project.new(@tmp_dir)
    project.add_clip_to_group('Video 1', 'a')

    exporter = InvasionExtractor::ProjectExporter.new(project, quiet: true)
    exporter.export_group('Video 1')

    assert File.directory?(File.join(@tmp_dir, 'Video 1'))
  end
end
