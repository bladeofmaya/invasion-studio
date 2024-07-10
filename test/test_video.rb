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
end
