require "test_helper"

class TestVideo < Minitest::Test
  def setup
    @video = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4")
  end

  def test_video_api
    processed_video = @video.generate_data!
    assert_equal 420, processed_video.frames.size
  end

  def test_generate_data!
    processed_video = @video.generate_data!
    assert_equal 420, processed_video.frames.size
  end

  def test_metadata
    assert_equal({ height: 720, width: 1280, fps: 60 }, @video.metadata)
  end
end
