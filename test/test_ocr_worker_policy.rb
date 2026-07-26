require 'test_helper'

class TestOCRWorkerPolicy < Minitest::Test
  def test_caps_default_worker_count_at_four
    policy = InvasionStudio::OCR::WorkerPolicy.new(processor_count: -> { 32 })

    assert_equal 4, policy.worker_count
    assert_equal 8, policy.queue_size
  end

  def test_uses_available_processors_when_fewer_than_four
    policy = InvasionStudio::OCR::WorkerPolicy.new(processor_count: -> { 2 })

    assert_equal 2, policy.worker_count
  end

  def test_explicit_worker_and_queue_options_override_defaults
    policy = InvasionStudio::OCR::WorkerPolicy.new(
      ocr_workers: 6,
      ocr_queue_size: 3,
      processor_count: -> { 2 }
    )

    assert_equal 6, policy.worker_count
    assert_equal 3, policy.queue_size
  end

  def test_rejects_non_positive_values
    assert_raises(ArgumentError) { InvasionStudio::OCR::WorkerPolicy.new(ocr_workers: 0) }
    assert_raises(ArgumentError) { InvasionStudio::OCR::WorkerPolicy.new(ocr_queue_size: -1) }
  end
end
