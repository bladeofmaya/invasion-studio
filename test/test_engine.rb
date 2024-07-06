require "test_helper"

class TestEngine < Minitest::Test
  def test_engine_api
    engine = InvasionExtractor::Engine.new(["test/samples/invasion-sample-720p.mp4"])

    assert_instance_of InvasionExtractor::Engine, engine
    assert_respond_to InvasionExtractor::Engine, :run!
  end
end
