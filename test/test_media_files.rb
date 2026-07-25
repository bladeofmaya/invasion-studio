require 'test_helper'

class TestMediaFiles < Minitest::Test
  def test_same_basename_with_different_extensions_gets_unique_ids
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, 'fight.mp4'), 'one')
      File.write(File.join(directory, 'fight.mkv'), 'two')

      ids = InvasionStudio::Project.new(directory).clips.map { |clip| clip['id'] }

      assert_equal 2, ids.uniq.length
    end
  end

  def test_video_extension_matching_is_case_insensitive
    assert InvasionStudio::MediaFiles.video?('clip.MP4')
    refute InvasionStudio::MediaFiles.video?('notes.txt')
  end
end
