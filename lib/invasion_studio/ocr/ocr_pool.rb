# frozen_string_literal: true

module InvasionStudio
  module OCR
    class OcrPool
      def initialize(provider:, worker_policy:, frame_discovery: FrameDiscovery.new,
                     progress_reporter_factory: ->(**options) { ProgressReporter.new(**options) })
        @provider = provider
        @worker_policy = worker_policy
        @frame_discovery = frame_discovery
        @progress_reporter_factory = progress_reporter_factory
      end

      def process(frames_dir:, producer:, fps:, total_frames:, video_path:,
                  extract_progress: nil, ocr_progress: nil)
        queue = SizedQueue.new(@worker_policy.queue_size)
        results = []
        results_mutex = Mutex.new
        reporter = @progress_reporter_factory.call(total: total_frames, callback: ocr_progress)
        workers = build_workers(queue, results, results_mutex, reporter, fps, video_path)

        begin
          discover_frames(frames_dir, producer, total_frames, extract_progress) do |path|
            enqueue(queue, path, workers)
          end
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
              path = queue.pop
              break if path == :done

              frame = recognize(path, fps, video_path)
              mutex.synchronize { results << frame }
              reporter.advance
            end
          end.tap { |worker| worker.report_on_exception = false }
        end
      end

      def recognize(path, fps, video_path)
        frame_number = File.basename(path).scan(/\d+/).first.to_i
        text = @provider.recognize(path)
        Frame.new(frame_number, text, timestamp(frame_number, fps), video_path)
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
