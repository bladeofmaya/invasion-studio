# frozen_string_literal: true

module InvasionStudio
  module OCR
    class WorkerPolicy
      DEFAULT_MAX_WORKERS = 4
      QUEUE_SLOTS_PER_WORKER = 2

      attr_reader :worker_count, :queue_size

      def initialize(ocr_workers: nil, ocr_queue_size: nil, processor_count: -> { Etc.nprocessors })
        @worker_count = Integer(ocr_workers || [processor_count.call, DEFAULT_MAX_WORKERS].min)
        @queue_size = Integer(ocr_queue_size || @worker_count * QUEUE_SLOTS_PER_WORKER)
        raise ArgumentError, 'OCR workers must be greater than zero' unless @worker_count.positive?
        raise ArgumentError, 'OCR queue size must be greater than zero' unless @queue_size.positive?
      end
    end
  end
end
