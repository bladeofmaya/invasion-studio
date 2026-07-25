require 'test_helper'

class TestClip < Minitest::Test
  def test_does_not_mutate_scanner_segment
    segment = InvasionStudio::Scanner::Segment.new('00:00:20', 'a.mp4', '00:00:30', 'a.mp4')

    first = InvasionStudio::Clip.new(segment)
    second = InvasionStudio::Clip.new(segment)

    assert_equal '00:00:20', segment.start_time
    assert_equal first.segment.start_time, second.segment.start_time
  end
end
