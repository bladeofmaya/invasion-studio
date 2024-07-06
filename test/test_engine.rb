require "test_helper"

class TestEngine < Minitest::Test
  def test_engine_system
    engine = InvasionExtractor::Engine.new(["test/samples/invasion-sample-720p.mp4"])

    assert_instance_of InvasionExtractor::Engine, engine
    assert_instance_of Array, engine.videos
    assert_instance_of InvasionExtractor::Video, engine.videos.first
    assert_equal 1, engine.videos.size

    engine.extract_invasion_clips!("invasion", "tmp/clips")


    expected_files = ["invasion_001.mp4", "invasion_002.mp4"]
    actual_files = Dir.glob(File.join("tmp/clips", "invasion_*.mp4")).map { |f| File.basename(f) }

    assert_equal expected_files.sort, actual_files.sort,
      "Expected files #{expected_files.inspect} in tmp/clips, but found #{actual_files.inspect}"

  end
end
