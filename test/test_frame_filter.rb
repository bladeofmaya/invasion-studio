require 'test_helper'

class TestFrameFilter < Minitest::Test
  def setup
    @filter = InvasionExtractor::FrameFilter.new
  end

  def test_should_process_returns_true_for_missing_file
    result = @filter.should_process?('/nonexistent/path.jpg')
    assert result, 'Should process missing files'
  end

  def test_should_process_dark_image
    skip 'No sample images available' unless File.exist?('test/samples/invasion_start.jpg')

    filter = InvasionExtractor::FrameFilter.new(brightness_threshold: 200)
    result = filter.should_process?('test/samples/invasion_start.jpg')
    assert_equal false, result, 'Should skip dark images'
  end

  def test_should_process_bright_image
    skip 'No sample images available' unless File.exist?('test/samples/invasion_start.jpg')

    # Use very low threshold since sample images are full screen and relatively dark
    filter = InvasionExtractor::FrameFilter.new(brightness_threshold: 5)
    result = filter.should_process?('test/samples/invasion_start.jpg')
    assert result, 'Should process images above threshold'
  end

  def test_stats_tracking
    @filter.should_process?('/nonexistent/path.jpg')
    stats = @filter.stats

    assert_equal 1, stats[:total]
    assert_equal 1, stats[:passed]
  end

  def test_reset_stats
    @filter.should_process?('/nonexistent/path.jpg')
    @filter.reset_stats!
    stats = @filter.stats

    assert_equal 0, stats[:total]
    assert_equal 0, stats[:passed]
  end

  def test_custom_thresholds
    filter = InvasionExtractor::FrameFilter.new(
      brightness_threshold: 50,
      edge_density_threshold: 0.05
    )

    assert_equal 50, filter.brightness_threshold
    assert_equal 0.05, filter.edge_density_threshold
  end
end
