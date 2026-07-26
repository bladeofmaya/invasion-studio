require 'test_helper'

class TestOCRWorkerPipeline < Minitest::Test
  class FailingProvider
    def recognize(_path)
      raise InvasionStudio::OCR::RecognitionError, 'OCR failed'
    end
  end

  class ManyFrames
    def each(_directory, producer:, total:, progress:)
      20.times { |index| yield format('/tmp/frame_%06d.jpg', index + 1) }
    end
  end

  def test_worker_failure_escapes_a_full_bounded_queue
    metadata = JSON.generate(
      streams: [{ codec_type: 'video', height: 720, width: 1280, r_frame_rate: '30/1', duration: '1' }]
    )
    runner = TestSupport::FakeProcessRunner.new(stdout: metadata)
    policy = InvasionStudio::OCR::WorkerPolicy.new(ocr_workers: 1, ocr_queue_size: 1)
    worker = InvasionStudio::OCRWorker.new(
      'video.mp4',
      FailingProvider.new,
      process_runner: runner,
      worker_policy: policy,
      frame_discovery: ManyFrames.new
    )

    error = assert_raises(InvasionStudio::OCR::RecognitionError) { worker.run! }

    assert_equal 'OCR failed', error.message
  end
end
