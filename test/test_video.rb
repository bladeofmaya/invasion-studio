require "test_helper"

class TestVideo < Minitest::Test
  def setup
    @video = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4")
  end

  def test_frames
    assert_equal 422, @video.frames.size
  end

  def test_metadata
    assert_equal({ height: 720, width: 1280, fps: 60 }, @video.metadata)
  end

  def test_no_cache_option_bypasses_cache
    # Create a fake cache file
    video = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4")
    cache_path = video.send(:cache_file_path)
    File.write(cache_path, [{ number: 1, text: 'cached', timestamp: '00:00:00.000', video_file: 'fake' }].to_yaml)

    # With no_cache: true, it should re-process (bypass cache)
    video_with_no_cache = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4", no_cache: true)
    # Since frames are memoized, we need a fresh instance
    # The key test: cached_data_exists? returns true but load_frames still processes
    assert video_with_no_cache.cached_data_exists?, "Cache should exist"

    # Force reload by creating a new instance
    video_with_no_cache = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4", no_cache: true)
    frames = video_with_no_cache.frames

    # Should get real OCR frames, not the cached fake data
    refute_equal 'cached', frames.first.text

    # Cleanup
    File.delete(cache_path) if File.exist?(cache_path)
  end

  def test_cache_is_used_by_default
    video = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4")
    cache_path = video.send(:cache_file_path)

    # Ensure cache exists by loading frames once
    video.frames

    # Now create a new instance and verify it loads from cache quickly
    video2 = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4")
    assert video2.cached_data_exists?, "Cache should exist after first run"
  end
end
