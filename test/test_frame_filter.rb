require 'test_helper'

class TestFrameFilter < Minitest::Test
  def setup
    @filter = InvasionExtractor::FrameFilter.new
  end

  def test_should_process_returns_true_for_missing_file
    result = @filter.should_process?('/nonexistent/path.jpg')
    assert result, 'Should process missing files'

    stats = @filter.stats
    assert_equal 1, stats[:total]
    assert_equal 1, stats[:passed]
  end

  def test_should_process_dark_image
    skip 'No sample images available' unless File.exist?('test/samples/invasion_start.jpg')

    filter = InvasionExtractor::FrameFilter.new(brightness_threshold: 200)
    result = filter.should_process?('test/samples/invasion_start.jpg')
    assert_equal false, result, 'Should skip dark images'

    stats = filter.stats
    assert stats[:skipped_dark] > 0, 'Should track dark skips'
  end

  def test_should_process_bright_image
    skip 'No sample images available' unless File.exist?('test/samples/invasion_start.jpg')

    # Use very low threshold since sample images are full screen and relatively dark
    filter = InvasionExtractor::FrameFilter.new(
      brightness_threshold: 5,
      edge_density_threshold: 0.01,
      text_like_threshold: 0.01
    )
    result = filter.should_process?('test/samples/invasion_start.jpg')
    assert result, 'Should process images above threshold'
  end

  def test_stats_tracking
    @filter.should_process?('/nonexistent/path.jpg')
    stats = @filter.stats

    assert_equal 1, stats[:total]
    assert_equal 1, stats[:passed]
    assert_equal 0, stats[:skipped_dark]
    assert_equal 0, stats[:skipped_edges]
    assert_equal 0, stats[:skipped_text]
  end

  def test_reset_stats
    @filter.should_process?('/nonexistent/path.jpg')
    @filter.reset_stats!
    stats = @filter.stats

    assert_equal 0, stats[:total]
    assert_equal 0, stats[:passed]
    assert_equal 0, stats[:skipped_dark]
    assert_equal 0, stats[:skipped_edges]
    assert_equal 0, stats[:skipped_text]
  end

  def test_custom_thresholds
    filter = InvasionExtractor::FrameFilter.new(
      brightness_threshold: 50,
      edge_density_threshold: 0.1,
      text_like_threshold: 0.05
    )

    assert_equal 50, filter.brightness_threshold
    assert_equal 0.1, filter.edge_density_threshold
    assert_equal 0.05, filter.text_like_threshold
  end

  def test_disabled_filter
    filter = InvasionExtractor::FrameFilter.new(enabled: false)

    skip 'No sample images available' unless File.exist?('test/samples/invasion_start.jpg')

    result = filter.should_process?('test/samples/invasion_start.jpg')
    assert result, 'Disabled filter should always return true'

    stats = filter.stats
    assert_equal 1, stats[:passed]
    assert_equal 0, stats[:skipped_dark]
  end

  def test_skip_rate_calculation
    assert_equal 0.0, @filter.skip_rate, 'Skip rate should be 0 with no frames'

    @filter.should_process?('/nonexistent/path1.jpg')
    @filter.should_process?('/nonexistent/path2.jpg')

    assert_equal 0.0, @filter.skip_rate, 'Skip rate should be 0 when all pass'
  end

  def test_handles_vips_errors_gracefully
    # Create a mock that will trigger an error
    filter = InvasionExtractor::FrameFilter.new

    # Test that it doesn't crash on bad data
    # This will fail Vips but should not crash
    result = filter.should_process?('/dev/null')
    # Should pass through on error
    assert result
  end

  def test_filters_with_different_thresholds
    skip 'No sample images available' unless File.exist?('test/samples/invasion_start.jpg')

    # Very permissive filter
    permissive = InvasionExtractor::FrameFilter.new(
      brightness_threshold: 1,
      edge_density_threshold: 0.001,
      text_like_threshold: 0.001
    )

    # Very strict filter
    strict = InvasionExtractor::FrameFilter.new(
      brightness_threshold: 250,
      edge_density_threshold: 0.9,
      text_like_threshold: 0.9
    )

    permissive_result = permissive.should_process?('test/samples/invasion_start.jpg')
    strict_result = strict.should_process?('test/samples/invasion_start.jpg')

    assert permissive_result, 'Permissive filter should pass'
    assert_equal false, strict_result, 'Strict filter should reject'
  end

  def test_stats_immutability
    @filter.should_process?('/nonexistent/path.jpg')
    stats = @filter.stats
    stats[:total] = 999

    fresh_stats = @filter.stats
    assert_equal 1, fresh_stats[:total], 'Stats should return a copy, not reference'
  end
end
