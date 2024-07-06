require "test_helper"

class TestVideo < Minitest::Test
  # def test_video_api
  #   video = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4")

  #   processed_video = video.generate_data!
  #   assert_equal 420, processed_video.frames.size
  # end

  def test_video_metadata
    video = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4")

    assert_equal({ height: 720, width: 1280, fps: 60 }, video.metadata)

    # processed_video = video.generate_metadata!
    # assert_equal 420, processed_video.frames.size
  end

  def test_generate_image_frames
    video = InvasionExtractor::Video.new("test/samples/invasion-sample-720p.mp4")

    video.generate_data!
    assert_equal 420, video.frames.size
  end

end
