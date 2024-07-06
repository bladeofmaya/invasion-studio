require "test_helper"

class TestOCRWorker < Minitest::Test
  def test_ocr_worker_run!

    result = InvasionExtractor::OCRWorker.new("test/samples/invasion-sample-720p.mp4").run!

    assert_instance_of Array, result
    assert_instance_of InvasionExtractor::Frame, result.first
    assert_equal 420, result.size
  end
end
