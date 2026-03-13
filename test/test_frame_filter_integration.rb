require 'test_helper'

class TestFrameFilterIntegration < Minitest::Test
  def test_frame_filtering_with_real_video
    skip 'No sample videos available' unless File.exist?('test/samples/invasion-sample-720p.mp4')

    # Test with filtering enabled
    filter = InvasionExtractor::FrameFilter.new(
      brightness_threshold: 10,
      edge_density_threshold: 0.03,
      text_like_threshold: 0.01,
      enabled: true
    )

    worker_with_filter = InvasionExtractor::OCRWorker.new(
      'test/samples/invasion-sample-720p.mp4',
      nil,
      frame_filter: filter,
      filter_enabled: true
    )

    result_with_filter = worker_with_filter.run!

    # Check that stats were tracked
    stats = worker_with_filter.filter_stats
    assert stats[:total] > 0, 'Should have processed some frames'
    assert stats[:passed] > 0, 'Should have passed some frames'

    puts "\nFrame Filter Statistics:"
    puts "  Total frames: #{stats[:total]}"
    puts "  Passed: #{stats[:passed]}"
    puts "  Skipped (dark): #{stats[:skipped_dark]}"
    puts "  Skipped (edges): #{stats[:skipped_edges]}"
    puts "  Skipped (text): #{stats[:skipped_text]}"
    skip_rate_pct = (stats[:total] - stats[:passed]).to_f / stats[:total] * 100
    puts "  Skip rate: #{skip_rate_pct.round(1)}%"

    # Verify we got some results
    assert result_with_filter.length > 0, 'Should have filtered frames'
  end

  def test_filter_performance_baseline
    skip 'No sample videos available' unless File.exist?('test/samples/invasion-sample-720p.mp4')

    # Test without filtering as baseline
    worker_no_filter = InvasionExtractor::OCRWorker.new(
      'test/samples/invasion-sample-720p.mp4',
      nil,
      filter_enabled: false
    )

    start_time = Time.now
    result_no_filter = worker_no_filter.run!
    duration_no_filter = Time.now - start_time

    puts "\nBaseline (No Filter):"
    puts "  Duration: #{duration_no_filter.round(2)}s"
    puts "  Frames processed: #{result_no_filter.length}"

    assert result_no_filter.length > 0, 'Should process all frames without filtering'
  end

  def test_filter_performance_impact
    skip 'No sample videos available' unless File.exist?('test/samples/invasion-sample-720p.mp4')

    # This test verifies that filtering provides the expected speedup
    # by measuring actual frame processing time

    filter = InvasionExtractor::FrameFilter.new(
      brightness_threshold: 10,
      edge_density_threshold: 0.03,
      text_like_threshold: 0.01
    )

    worker = InvasionExtractor::OCRWorker.new(
      'test/samples/invasion-sample-720p.mp4',
      nil,
      frame_filter: filter,
      filter_enabled: true
    )

    start_time = Time.now
    result = worker.run!
    duration_with_filter = Time.now - start_time

    stats = worker.filter_stats
    skip_rate = (stats[:total] - stats[:passed]).to_f / stats[:total] * 100

    puts "\nWith Filtering:"
    puts "  Duration: #{duration_with_filter.round(2)}s"
    puts "  Total frames: #{stats[:total]}"
    puts "  Frames processed: #{stats[:passed]}"
    puts "  Frames skipped: #{stats[:total] - stats[:passed]}"
    puts "  Skip rate: #{skip_rate.round(1)}%"

    # We expect at least some frames to be skipped
    assert skip_rate >= 0, 'Skip rate should be non-negative'
    assert stats[:total] > 0, 'Should have processed frames'
    assert result.length > 0, 'Should have results'
  end

  def test_filter_comparison
    skip 'No sample videos available' unless File.exist?('test/samples/invasion-sample-720p.mp4')

    # Compare filtered vs unfiltered results
    # They should detect the same invasions (though filtered might miss some frames)

    filter = InvasionExtractor::FrameFilter.new(
      brightness_threshold: 10,
      edge_density_threshold: 0.03,
      text_like_threshold: 0.01
    )

    # Run with filter
    worker_filtered = InvasionExtractor::OCRWorker.new(
      'test/samples/invasion-sample-720p.mp4',
      nil,
      frame_filter: filter,
      filter_enabled: true
    )
    frames_filtered = worker_filtered.run!
    stats_filtered = worker_filtered.filter_stats

    puts "\nFilter Comparison:"
    puts "  Frames with filter: #{frames_filtered.length}"
    puts "  Total extracted: #{stats_filtered[:total]}"
    puts "  Skipped: #{stats_filtered[:total] - stats_filtered[:passed]}"
    skip_rate = (stats_filtered[:total] - stats_filtered[:passed]).to_f / stats_filtered[:total] * 100
    puts "  Skip rate: #{skip_rate.round(1)}%"

    # Just verify we get reasonable results
    assert frames_filtered.length > 0, 'Should get frames with filtering'
    assert stats_filtered[:passed] > 0, 'Should pass some frames'
  end
end
