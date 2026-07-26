require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestProjectExporter < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_export_group_with_no_clips_raises
    project = InvasionStudio::Project.new(@tmp_dir)
    exporter = InvasionStudio::ProjectExporter.new(project, quiet: true)

    assert_raises(InvasionStudio::Error) do
      exporter.export_group('Video 1')
    end
  end
end
