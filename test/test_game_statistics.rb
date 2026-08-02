require 'test_helper'

class TestGameStatistics < Minitest::Test
  Clip = Struct.new(:attributes) do
    def [](key) = attributes[key]
  end

  Project = Struct.new(:clips)

  def test_reports_invasion_results_duration_and_decided_win_rate
    clips = [
      clip('win', 90.5), clip('win', 30), clip('loss', 60),
      clip('dc', 15), clip(nil, nil)
    ]

    stats = InvasionStudio::Webui::GameStatistics.new(Project.new(clips)).call

    assert_equal 5, stats['invasions']
    assert_in_delta 195.5, stats['duration_seconds']
    assert_equal({ 'won' => 2, 'lost' => 1, 'dc' => 1, 'no_result' => 1 }, stats['results'])
    assert_in_delta 66.67, stats['win_rate']
  end

  def test_win_rate_is_nil_without_decided_invasions
    stats = InvasionStudio::Webui::GameStatistics.new(
      Project.new([clip('dc', 10), clip(nil, 20)])
    ).call

    assert_nil stats['win_rate']
  end

  private

  def clip(result, duration)
    Clip.new({ 'result' => result, 'duration' => duration })
  end
end
