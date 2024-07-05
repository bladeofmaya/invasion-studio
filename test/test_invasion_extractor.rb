# frozen_string_literal: true

require "test_helper"

class TestInvasionExtractor < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::InvasionExtractor::VERSION
  end



  def test_api_structure
    processor = InvasionExtractor::Engine.new(["test/samples/invasion-sample-720p.mp4"])

    assert_instance_of InvasionExtractor::Engine, processor




  end
end
