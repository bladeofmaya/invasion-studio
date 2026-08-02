require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestProjectClipImporter < Minitest::Test
  def setup
    @project_dir = Dir.mktmpdir
    @source_dir = Dir.mktmpdir
    @project = InvasionStudio::Project.new(@project_dir)
  end

  def teardown
    FileUtils.rm_rf(@project_dir)
    FileUtils.rm_rf(@source_dir)
  end

  def test_imports_files_in_order_with_sequential_names_and_preserved_extensions
    first = source('first fight.mkv')
    second = source('second fight.mp4')

    imported = InvasionStudio::ProjectClipImporter.new(@project).import([first, second])

    assert_equal %w[clip_00001.mkv clip_00002.mp4], imported.map { |clip| clip['filename'] }
    assert_equal 'first fight.mkv', imported[0]['source_video']
    assert_equal 'second fight.mp4', imported[1]['source_video']
    assert imported.all? { |clip| clip['source_kind'] == 'imported' }
    assert_equal 'first', File.read(File.join(@project_dir, 'clips', 'clip_00001.mkv'))
    assert_equal 'second', File.read(File.join(@project_dir, 'clips', 'clip_00002.mp4'))
  end

  def test_continues_after_highest_registered_or_loose_clip_number
    source_path = source('new.mov')
    FileUtils.mkdir_p(File.join(@project_dir, 'clips'))
    File.write(File.join(@project_dir, 'clips', 'clip_00007.mp4'), 'existing')
    @project.sync_clips!
    File.write(File.join(@project_dir, 'clips', 'other_00009.mkv'), 'loose')

    imported = InvasionStudio::ProjectClipImporter.new(@project).import([source_path])

    assert_equal 'clip_00010.mov', imported.first['filename']
  end

  def test_rejects_unsupported_files_before_copying_anything
    video = source('valid.mp4')
    text = source('notes.txt')

    error = assert_raises(InvasionStudio::Error) do
      InvasionStudio::ProjectClipImporter.new(@project).import([video, text])
    end

    assert_match(/Unsupported file type/, error.message)
    assert_empty Dir.glob(File.join(@project_dir, 'clips', '*'))
  end

  private

  def source(name)
    path = File.join(@source_dir, name)
    File.write(path, name.start_with?('first') ? 'first' : name.start_with?('second') ? 'second' : 'video')
    path
  end
end
