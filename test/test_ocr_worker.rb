require 'test_helper'

class TestOCRWorker < Minitest::Test
  def test_ocr_worker_run!
    result = InvasionExtractor::OCRWorker.new('test/samples/invasion-sample-720p.mp4', nil, filter_enabled: false).run!

    assert_instance_of Array, result
    assert_instance_of InvasionExtractor::Frame, result.first
    assert_equal 422, result.size
  end

  def test_ocr_worker_with_frame_filter
    worker = InvasionExtractor::OCRWorker.new('test/samples/invasion-sample-720p.mp4', nil, filter_enabled: true)
    result = worker.run!

    assert_instance_of Array, result
    assert result.size <= 422, 'Frame filtering should reduce or maintain frame count'

    stats = worker.filter_stats
    assert stats[:total] > 0, 'Should have processed some frames'
    assert stats[:passed] > 0, 'Should have passed some frames'
  end

  def test_ocr_worker_with_progress_callback
    progress_events = []
    callback = ->(event, current, total) { progress_events << [event, current, total] }

    worker = InvasionExtractor::OCRWorker.new('test/samples/invasion-sample-720p.mp4', nil,
                                              filter_enabled: false,
                                              progress_callback: callback)
    result = worker.run!

    assert result.length > 0, 'Should process frames'
    assert progress_events.any? { |e| e[0] == :extracting_frames }, 'Should report frame extraction'
    assert progress_events.any? { |e| e[0] == :processing_ocr }, 'Should report OCR processing'
  end
end
