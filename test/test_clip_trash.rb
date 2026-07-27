require 'test_helper'

class TestClipTrash < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @source = File.join(@directory, 'fight.mp4')
    File.write(@source, 'video')
    @clip = { 'id' => 'fight', 'filename' => 'fight.mp4', 'path' => 'fight.mp4', 'deleted' => false }
    @storage = TestSupport::FakeStorage.new(@directory)
    @trash = InvasionStudio::ClipTrash.new(
      @directory,
      @storage,
      clock: -> { Time.at(123) },
      random_suffix: -> { 'abcd' }
    )
  end

  def teardown
    FileUtils.rm_rf(@directory)
  end

  def test_delete_and_restore_round_trip
    assert @trash.delete(@clip)
    assert @clip['deleted']
    refute File.exist?(@source)
    assert File.exist?(File.join(@directory, @clip['trash_path']))

    assert @trash.restore(@clip)
    refute @clip['deleted']
    assert File.exist?(@source)
    refute @clip.key?('trash_path')
  end

  def test_delete_uses_collision_safe_destination
    trash_dir = File.join(@directory, '.trashed')
    FileUtils.mkdir_p(trash_dir)
    File.write(File.join(trash_dir, 'fight.mp4'), 'old')

    @trash.delete(@clip)

    assert_equal '.trashed/fight_123_abcd.mp4', @clip['trash_path']
    assert_equal 'old', File.read(File.join(trash_dir, 'fight.mp4'))
  end

  def test_restore_refuses_to_overwrite_source
    @trash.delete(@clip)
    File.write(@source, 'replacement')

    refute @trash.restore(@clip)
    assert @clip['deleted']
    assert_equal 'replacement', File.read(@source)
  end
end
