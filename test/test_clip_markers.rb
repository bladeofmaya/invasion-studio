require 'test_helper'

class TestClipMarkers < Minitest::Test
  def test_finalization_removes_cut_events_and_shifts_remaining_events
    markers = [1, 2, 4, 6, 8, 12].map do |time|
      { 'id' => time.to_s, 'time' => time.to_f, 'event_type' => 'custom', 'label' => '' }
    end
    plan = InvasionStudio::CutPlan.build([{ start: 2, end: 5 }, { start: 4, end: 6 }, { start: 8, end: 10 }])
    result = InvasionStudio::ClipMarkers.after_cuts(markers, plan)
    assert_equal %w[1 6 12], result.map { |marker| marker['id'] }
    assert_equal [1.0, 2.0, 6.0], result.map { |marker| marker['time'] }
    assert_equal 12.0, markers.last['time']
  end
end
