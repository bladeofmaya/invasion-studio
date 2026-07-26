require 'test_helper'

class TestCutPlan < Minitest::Test
  def test_build_normalizes_and_merges_without_mutating_input
    input = [{ 'start' => 4, 'end' => 8 }, { start: 1, end: 5 }]

    plan = InvasionStudio::CutPlan.build(input)

    assert_equal [{ 'start' => 1.0, 'end' => 8.0 }], plan.cuts
    assert_equal [{ 'start' => 4, 'end' => 8 }, { start: 1, end: 5 }], input
    assert plan.frozen?
    assert plan.cuts.frozen?
  end

  def test_build_rejects_invalid_cut_data
    assert_nil InvasionStudio::CutPlan.build('invalid')
    assert_nil InvasionStudio::CutPlan.build([{ start: -1, end: 2 }])
    assert_nil InvasionStudio::CutPlan.build([{ start: 2, end: 2 }])
    assert_nil InvasionStudio::CutPlan.build([{ start: Float::NAN, end: 2 }])
  end

  def test_effective_duration_clamps_cuts_to_media_bounds
    plan = InvasionStudio::CutPlan.build([{ start: 2, end: 4 }, { start: 8, end: 20 }])

    assert_in_delta 6.0, plan.effective_duration(12.0)
    assert_equal 0.0, plan.effective_duration('invalid')
  end

  def test_keep_segments_invert_the_cut_plan
    plan = InvasionStudio::CutPlan.build([{ start: 2, end: 4 }, { start: 7, end: 10 }])

    assert_equal [
      { start: 0.0, end: 2.0 },
      { start: 4.0, end: 7.0 }
    ], plan.keep_segments(10.0)
  end

  def test_keep_segments_are_empty_when_everything_is_cut
    plan = InvasionStudio::CutPlan.build([{ start: 0, end: 20 }])

    assert_equal [], plan.keep_segments(10.0)
  end
end
