require 'test_helper'

class TestScanner < Minitest::Test
  FakeVideo = Data.define(:path, :frames)

  def test_unclosed_invasion_ends_at_last_video
    first = FakeVideo.new('first.mp4', [frame(1, 'Defeat the Host of Fingers', '00:00:02', 'first.mp4')])
    second = FakeVideo.new('second.mp4', [frame(1, '', '00:00:10', 'second.mp4')])

    segment = InvasionStudio::Scanner.new([first, second]).invasion_segments.fetch(0)

    assert_equal 'second.mp4', segment.end_video
    assert_equal '00:00:10', segment.end_time
  end

  def test_empty_trailing_video_does_not_crash
    first = FakeVideo.new('first.mp4', [frame(1, 'Defeat the Host of Fingers', '00:00:02', 'first.mp4')])
    second = FakeVideo.new('second.mp4', [])

    segment = InvasionStudio::Scanner.new([first, second]).invasion_segments.fetch(0)

    assert_equal 'first.mp4', segment.end_video
    assert_equal '00:00:02', segment.end_time
  end

  private

  def frame(number, text, timestamp, path)
    InvasionStudio::Frame.new(number, text, timestamp, path)
  end
end
