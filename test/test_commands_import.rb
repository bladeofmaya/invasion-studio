require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestCommandsImport < Minitest::Test
  def setup
    @project_dir = Dir.mktmpdir
    @source_dir = Dir.mktmpdir
    @first = File.join(@source_dir, 'one.mp4')
    @second = File.join(@source_dir, 'two.mkv')
    File.write(@first, 'one')
    File.write(@second, 'two')
  end

  def teardown
    FileUtils.rm_rf(@project_dir)
    FileUtils.rm_rf(@source_dir)
  end

  def test_parser_accepts_project_and_clip_list
    options = { command: 'import' }
    command = InvasionStudio::Commands::Import.new(
      options, ['--project', @project_dir, @first, @second]
    )

    command.send(:parse_options!)
    command.send(:validate!)

    assert_equal @project_dir, options[:project]
    assert_equal [@first, @second], command.argv
  end

  def test_run_imports_all_clips
    command = InvasionStudio::Commands::Import.new(
      { command: 'import', quiet: true }, ['--project', @project_dir, @first, @second]
    )

    command.run

    assert File.exist?(File.join(@project_dir, 'clips', 'clip_00001.mp4'))
    assert File.exist?(File.join(@project_dir, 'clips', 'clip_00002.mkv'))
  end
end
