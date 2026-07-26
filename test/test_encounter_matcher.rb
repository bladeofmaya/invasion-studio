require 'test_helper'

class TestEncounterMatcher < Minitest::Test
  def setup
    @matcher = InvasionStudio::EncounterMatcher.new
  end

  def test_classifies_invasion_and_arena_markers
    assert_equal :start, @matcher.classify('Defeat the Host of Fingers')
    assert_equal :end, @matcher.classify('Returning to your world')
    assert_equal :start, @matcher.classify('Commencing combat')
    assert_equal :end, @matcher.classify('Combat ends')
    assert_nil @matcher.classify('You Died')
  end

  def test_scanner_accepts_an_injected_matcher
    matcher = Object.new
    matcher.define_singleton_method(:classify) { |text| { 'BEGIN' => :start, 'DONE' => :end }[text] }
    frames = [
      InvasionStudio::Frame.new(1, 'BEGIN', '00:00:01', 'custom.mp4'),
      InvasionStudio::Frame.new(2, 'DONE', '00:00:03', 'custom.mp4')
    ]
    video = Struct.new(:path, :frames).new('custom.mp4', frames)

    segment = InvasionStudio::Scanner.new([video], matcher: matcher).invasion_segments.fetch(0)

    assert_equal '00:00:01', segment.start_time
    assert_equal '00:00:03', segment.end_time
  end
end
