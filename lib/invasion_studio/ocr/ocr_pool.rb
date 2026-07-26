# frozen_string_literal: true

module InvasionStudio
  module OCR
    class OcrPool
      def initialize(provider:, worker_policy:, frame_discovery: FrameDiscovery.new,
                     progress_reporter_factory: ->(**options) { ProgressReporter.new(**options) },
                     batch_size: 1)
        @provider = provider
        @worker_policy = worker_policy
        @frame_discovery = frame_discovery
        @progress_reporter_factory = progress_reporter_factory
        @batch_size = Integer(batch_size)
        raise ArgumentError, 'OCR batch size must be greater than zero' unless @batch_size.positive?
      end

      def process(frames_dir:, producer:, fps:, total_frames:, video_path:,
                  extract_progress: nil, ocr_progress: nil)
        queue = SizedQueue.new(@worker_policy.queue_size)
        results = []
        results_mutex = Mutex.new
        reporter = @progress_reporter_factory.call(total: total_frames, callback: ocr_progress)
        workers = build_workers(queue, results, results_mutex, reporter, fps, video_path)

        begin
          enqueue_discovered_batches(
            queue, workers, frames_dir, producer, total_frames, extract_progress
          )
          workers.each { enqueue(queue, :done, workers) }
          workers.each(&:value)
        ensure
          workers.each(&:kill)
        end

        results
      end

      private

      def build_workers(queue, results, mutex, reporter, fps, video_path)
        @worker_policy.worker_count.times.map do
          Thread.new do
            loop do
              paths = queue.pop
              break if paths == :done

              frames = recognize_batch(paths, fps, video_path)
              mutex.synchronize { results.concat(frames) }
              frames.each { reporter.advance }
            end
          end.tap { |worker| worker.report_on_exception = false }
        end
      end

      def recognize_batch(paths, fps, video_path)
        texts = if @batch_size > 1 && @provider.respond_to?(:recognize_batch)
          @provider.recognize_batch(paths)
        else
          paths.map { |path| @provider.recognize(path) }
        end
        unless texts.length == paths.length
          raise RecognitionError, "OCR provider returned #{texts.length} result for #{paths.length} images"
        end

        paths.zip(texts).map do |path, text|
          frame_number = File.basename(path).scan(/\d+/).first.to_i
          Frame.new(frame_number, text, timestamp(frame_number, fps), video_path)
        end
      end

      def timestamp(frame_number, fps)
        seconds = (frame_number - 1) / fps.to_f
        minutes, seconds = seconds.divmod(60)
        hours, minutes = minutes.divmod(60)
        format('%02d:%02d:%06.3f', hours, minutes, seconds)
      end

      def discover_frames(directory, producer, total, progress, &block)
        @frame_discovery.each(
          directory,
          producer: producer,
          total: total,
          progress: progress,
          &block
        )
      end

      def enqueue_discovered_batches(queue, workers, directory, producer, total, progress)
        batch = []
        discover_frames(directory, producer, total, progress) do |path|
          batch << path
          if batch.length == @batch_size
            enqueue(queue, batch, workers)
            batch = []
          end
        end
        enqueue(queue, batch, workers) unless batch.empty?
      end

      def enqueue(queue, item, workers)
        queue.push(item, true)
      rescue ThreadError
        finished_worker = workers.find { |worker| !worker.alive? }
        finished_worker.value if finished_worker
        sleep 0.01
        retry
      end
    end
  end
end
