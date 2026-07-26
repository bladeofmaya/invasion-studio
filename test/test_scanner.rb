require 'test_helper'

class TestScanner < Minitest::Test
  FakeVideo = Data.define(:path, :frames)

  class CountingVideo
    attr_reader :path, :frames_calls

    def initialize(path, frames)
      @path = path
      @frames = frames
      @frames_calls = 0
    end

    def frames
      @frames_calls += 1
      @frames
    end
  end

  def test_matches_are_collected_once_and_reused
    video = CountingVideo.new('video.mp4', [
      frame(1, 'Defeat the Host of Fingers', '00:00:02', 'video.mp4'),
      frame(2, 'Returning to your world', '00:00:10', 'video.mp4')
    ])

    scanner = InvasionStudio::Scanner.new([video])

    assert_equal 2, scanner.matched_frames.length
    assert_equal 1, scanner.invasion_segments.length
    assert_equal 1, video.frames_calls
  end

  def test_unclosed_segment_reuses_last_frame_from_initial_traversal
    first = CountingVideo.new('first.mp4', [
      frame(1, 'Defeat the Host of Fingers', '00:00:02', 'first.mp4')
    ])
    second = CountingVideo.new('second.mp4', [
      frame(1, '', '00:00:10', 'second.mp4')
    ])

    segment = InvasionStudio::Scanner.new([first, second]).invasion_segments.fetch(0)

    assert_equal 'second.mp4', segment.end_video
    assert_equal [1, 1], [first.frames_calls, second.frames_calls]
  end

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

  def test_leading_end_marker_starts_segment_at_video_start
    video = FakeVideo.new('arena.mp4', [
      frame(1, 'Combat ends', '00:00:05', 'arena.mp4')
    ])

    segment = InvasionStudio::Scanner.new([video]).invasion_segments.fetch(0)

    assert_equal '00:00:00', segment.start_time
    assert_equal '00:00:05', segment.end_time
  end

  def test_repeated_start_marker_uses_the_latest_match
    video = FakeVideo.new('video.mp4', [
      frame(1, 'Defeat the Host of Fingers', '00:00:02', 'video.mp4'),
      frame(2, 'Defeat the Host of Fingers', '00:00:04', 'video.mp4'),
      frame(3, 'Returning to your world', '00:00:10', 'video.mp4')
    ])

    segment = InvasionStudio::Scanner.new([video]).invasion_segments.fetch(0)

    assert_equal '00:00:04', segment.start_time
  end

  def test_arena_markers_create_a_segment
    video = FakeVideo.new('arena.mp4', [
      frame(1, 'Commencing combat', '00:00:02', 'arena.mp4'),
      frame(2, 'Combat ends', '00:00:08', 'arena.mp4')
    ])

    assert_equal 1, InvasionStudio::Scanner.new([video]).invasion_segments.length
  end

  private

  def frame(number, text, timestamp, path)
    InvasionStudio::Frame.new(number, text, timestamp, path)
  end
end
