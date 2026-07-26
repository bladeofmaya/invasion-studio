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

  class BatchProvider
    attr_reader :batches

    def initialize
      @batches = []
    end

    def recognize_batch(paths)
      @batches << paths
      paths.map { |path| File.basename(path, '.jpg') }
    end
  end

  class FiveFrames
    def each(_directory, producer:, total:, progress:)
      5.times { |index| yield format('/tmp/frame_%06d.jpg', index + 1) }
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

  def test_groups_discovered_paths_into_bounded_batches
    provider = BatchProvider.new
    policy = InvasionStudio::OCR::WorkerPolicy.new(ocr_workers: 1, ocr_queue_size: 1)
    pool = InvasionStudio::OCR::OcrPool.new(
      provider: provider,
      worker_policy: policy,
      frame_discovery: FiveFrames.new,
      batch_size: 2
    )

    results = pool.process(
      frames_dir: '/tmp', producer: Object.new, fps: 1,
      total_frames: 5, video_path: 'video.mp4'
    ).sort_by(&:number)

    assert_equal [2, 2, 1], provider.batches.map(&:length)
    assert_equal 5, results.length
    assert_equal 'frame_000001', results.first.text
  end
end
