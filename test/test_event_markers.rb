require 'test_helper'

class TestEventMarkers < Minitest::Test
  Video = Struct.new(:path, :frames, :metadata)

  def frame(seconds, text, path = 'a.mp4')
    InvasionStudio::Frame.new(seconds, text, format('00:%02d:%06.3f', seconds / 60, seconds % 60), path)
  end

  def segment(start_time = '00:00:10.000', end_time = '00:00:40.000', end_video = 'a.mp4')
    InvasionStudio::Scanner::Segment.new(start_time, 'a.mp4', end_time, end_video)
  end

  def test_deaths_become_clip_relative_markers_and_repeated_frames_are_deduplicated
    video = Video.new('a.mp4', [
      frame(4, 'Hunter Early has died'),
      frame(12, 'Furled Finger reaper2point0 has died'),
      frame(13, "Furled  Finger reaper2point0\nhas died"),
      frame(16, 'Hunter Roxis_7 summoned'),
      frame(20, 'Hunter Roxis_7 has died'),
      frame(21, 'Hunter Roxis_7 has died'),
      frame(25, 'Hunter Other has died'),
      frame(40, 'Hunter Outside has died')
    ], { duration: 60 })
    detector = InvasionStudio::Extraction::EventMarkers.new([video])
    markers = detector.for_segment(segment)
    assert_equal %w[phantom_defeated hunter_defeated hunter_defeated], markers.map { |marker| marker['event_type'] }
    assert_equal [0.0, 2.0, 7.0], markers.map { |marker| marker['time'] }
    assert_equal %w[reaper2point0 Roxis_7 Other], markers.map { |marker| marker['label'] }
    assert_equal markers, detector.for_segment(segment)
  end

  def test_padding_and_clamped_start_are_respected
    video = Video.new('a.mp4', [frame(8, 'Furled Finger Alice has died')], { duration: 60 })
    detector = InvasionStudio::Extraction::EventMarkers.new([video])
    clip = InvasionStudio::Clip.new(segment('00:00:05', '00:00:20'), pad_start: 10, pad_end: 2)
    assert_equal 0.0, detector.for_segment(clip.segment).first['time']
  end

  def test_both_red_invader_titles_use_invader_markers_with_the_death_offset
    video = Video.new('a.mp4', [
      frame(12, 'Bloody Finger MuRo_TR- has died'),
      frame(13, "bloody  finger MuRo_TR-\nhas died"),
      frame(25, 'Recusant Red Wolf has died'),
      frame(26, 'Recusant Red Wolf has died'),
      frame(30, 'Bloody Finger Someone has invaded'),
      frame(31, 'Recusant Another has returned to their world')
    ], { duration: 60 })
    detector = InvasionStudio::Extraction::EventMarkers.new([video])
    markers = detector.for_segment(segment)
    assert_equal %w[invader_defeated invader_defeated], markers.map { |marker| marker['event_type'] }
    assert_equal ['MuRo_TR-', 'Red Wolf'], markers.map { |marker| marker['label'] }
    assert_equal [0.0, 7.0], markers.map { |marker| marker['time'] }
    assert_equal markers, detector.for_segment(segment)
    assert_equal markers, InvasionStudio::ClipMarkers.normalize(markers, duration: 30)
    assert_equal markers, InvasionStudio::ClipMarkers.merge_detected(markers, detector.for_segment(segment))
  end

  def test_cross_recording_offsets_and_banner_duplicates
    videos = [
      Video.new('a.mp4', [frame(58, 'Hunter Alice has died')], { duration: 60 }),
      Video.new('b.mp4', [frame(0, 'Hunter Alice has died', 'b.mp4'), frame(5, 'Furled Finger Bob has died', 'b.mp4')], { duration: 20 })
    ]
    markers = InvasionStudio::Extraction::EventMarkers.new(videos).for_segment(segment('00:00:50', '00:00:10', 'b.mp4'))
    assert_equal [0.0, 7.0], markers.map { |marker| marker['time'] }
    assert_equal %w[Alice Bob], markers.map { |marker| marker['label'] }
  end

  def test_separate_occurrences_of_the_same_message_are_retained
    video = Video.new('a.mp4', [12, 13, 30].map { |time| frame(time, 'Hunter Alice has died') }, { duration: 60 })
    markers = InvasionStudio::Extraction::EventMarkers.new([video]).for_segment(segment)
    assert_equal [0.0, 12.0], markers.map { |marker| marker['time'] }
  end

  def test_delay_is_applied_after_cross_recording_offsets_with_fractional_precision
    videos = [
      Video.new('a.mp4', [], { duration: 60 }),
      Video.new('b.mp4', [frame(3.5, 'Hunter Alice has died', 'b.mp4')], { duration: 20 })
    ]
    markers = InvasionStudio::Extraction::EventMarkers.new(videos).for_segment(segment('00:00:50', '00:00:10', 'b.mp4'))
    assert_equal 5.5, markers.first['time']
  end

  def test_marker_identity_stays_based_on_banner_time_for_repeat_scans
    video = Video.new('a.mp4', [frame(20, 'Hunter Alice has died')], { duration: 60 })
    marker = InvasionStudio::Extraction::EventMarkers.new([video]).for_segment(segment).first
    id = "ocr-#{Digest::SHA256.hexdigest(['hunter_defeated', 'alice', 10.0].join('|'))[0, 32]}"
    assert_equal id, marker['id']
    assert_equal 2.0, marker['time']
  end
end
