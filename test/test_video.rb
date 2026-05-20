require "test_helper"

class TestVideo < Minitest::Test
  def setup
    @video = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4")
  end

  def test_frames
    assert_equal 420, @video.frames.size
  end

  def test_metadata
    meta = @video.metadata
    assert_equal 720, meta[:height]
    assert_equal 1280, meta[:width]
    assert_equal 60, meta[:fps]
    assert meta[:duration] > 0, "Expected duration to be present"
  end

  def test_no_cache_option_bypasses_cache
    video = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4")
    cache_path = video.send(:cache_file_path)
    File.write(cache_path, [{ number: 1, text: 'cached', timestamp: '00:00:00.000', video_path: 'fake' }].to_yaml)

    video_with_no_cache = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4", no_cache: true)
    assert video_with_no_cache.cached_data_exists?, "Cache should exist"

    video_with_no_cache = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4", no_cache: true)
    frames = video_with_no_cache.frames

    refute_equal 'cached', frames.first.text

    File.delete(cache_path) if File.exist?(cache_path)
  end

  def test_cache_is_used_by_default
    video = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4")
    cache_path = video.send(:cache_file_path)

    video.frames

    video2 = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4")
    assert video2.cached_data_exists?, "Cache should exist after first run"
  end
end
