module InvasionStudio
  class OCRWorker
    attr_reader :video_path, :video_metadata

    def initialize(video_path, ocr_provider = nil, options = {})
      @video_path = video_path
      @process_runner = options[:process_runner] || ProcessRunner.new
      @video_metadata = get_metadata
      @ocr_provider = ocr_provider || InvasionStudio::OCR::TesseractProvider.new
      @options = options
      @worker_policy = options[:worker_policy] || OCR::WorkerPolicy.new(
        ocr_workers: options[:ocr_workers],
        ocr_queue_size: options[:ocr_queue_size]
      )
      @frame_discovery = options[:frame_discovery] || OCR::FrameDiscovery.new
    end

    def run!
      fps = @options[:fps] || 1
      extract_progress = @options[:extract_progress_callback]

      Dir.mktmpdir do |frames_dir|
        ffmpeg_thread = extract_frames(frames_dir, fps)
        results = run_ocr_pipeline(frames_dir, fps, ffmpeg_thread, extract_progress)
        ffmpeg_thread.value
        results.sort_by(&:number)
      end
    end

    private

    def run_ocr_pipeline(frames_dir, fps, ffmpeg_thread, extract_progress)
      queue = SizedQueue.new(@worker_policy.queue_size)
      results = []
      mutex = Mutex.new
      total_frames = estimated_total_frames(fps)

      # ponytail: manual thread pool instead of Parallel gem; tesseract shell-out
      # releases the GIL, so threads parallelize nearly as well as processes
      # without fork overhead. ceiling: GIL contention on pure Ruby work.
      workers = @worker_policy.worker_count.times.map do
        Thread.new do
          loop do
            item = queue.pop
            break if item == :done

            path = item
            text = @ocr_provider.recognize(path)
            frame_number = extract_frame_number(path)
            timestamp = frame_number_to_timestamp(frame_number, fps)

            mutex.synchronize do
              results << Frame.new(frame_number, text, timestamp, @video_path)
              @ocr_progress += 1 if @options[:progress_callback]
            end
          end
        end.tap { |worker| worker.report_on_exception = false }
      end

      @ocr_progress = 0 if @options[:progress_callback]

      pipeline_done = false
      monitor = if @options[:progress_callback] && total_frames > 0
        Thread.new do
          loop do
            @options[:progress_callback].call(@ocr_progress, total_frames)
            break if pipeline_done
            sleep 0.3
          end
        end
      end

      begin
        @frame_discovery.each(
          frames_dir,
          producer: ffmpeg_thread,
          total: total_frames,
          progress: extract_progress
        ) do |path|
          enqueue(queue, path, workers)
        end

        workers.each { enqueue(queue, :done, workers) }
        workers.each(&:value)
      ensure
        workers.each(&:kill)
        pipeline_done = true
        monitor&.join
      end
      @options[:progress_callback]&.call(results.length, total_frames)

      results
    end

    def enqueue(queue, item, workers)
      queue.push(item, true)
    rescue ThreadError
      failed_worker = workers.find { |worker| !worker.alive? }
      failed_worker.value if failed_worker
      sleep 0.01
      retry
    end

    def extract_frames(frames_dir, fps)
      crop = calculate_crop
      filter = "fps=#{fps},crop=#{crop[:width]}:#{crop[:height]}:#{crop[:x]}:#{crop[:y]}"

      hwaccel_args = []
      if @options[:hwaccel] && GPUDetector.vaapi_available?
        hwaccel_args = GPUDetector.ffmpeg_hwaccel_args
        filter = "fps=#{fps},hwdownload,format=nv12,crop=#{crop[:width]}:#{crop[:height]}:#{crop[:x]}:#{crop[:y]}"
      end

      threads = @options[:ffmpeg_threads] || 4
      cmd = ['ffmpeg', '-threads', threads.to_s, *hwaccel_args, '-i', @video_path,
             '-vf', filter, '-qscale:v', '5', File.join(frames_dir, 'frame_%06d.jpg')]

      Thread.new do
        success = @process_runner.run(*cmd, log_path: File::NULL)
        raise Error, "ffmpeg failed while extracting frames from #{@video_path}" unless success

        true
      end
    end

    def extract_frame_number(path)
      File.basename(path).scan(/\d+/).first.to_i
    end

    def estimated_total_frames(fps)
      @video_metadata && @video_metadata[:duration] > 0 ?
        (@video_metadata[:duration] * fps).to_i : 0
    end

    def calculate_crop
      base_height = 1440
      base_crop_width = 700
      base_crop_height = 130
      base_crop_x = 950
      base_crop_y = 960

      height = @video_metadata ? @video_metadata[:height] : base_height
      scale_factor = height.to_f / base_height

      {
        width: ((base_crop_width * scale_factor).to_i / 2) * 2,
        height: ((base_crop_height * scale_factor).to_i / 2) * 2,
        x: ((base_crop_x * scale_factor).to_i / 2) * 2,
        y: ((base_crop_y * scale_factor).to_i / 2) * 2
      }
    end

    def get_metadata
      result = @process_runner.capture('ffprobe', '-v', 'quiet', '-print_format', 'json',
                                       '-show_streams', @video_path)
      raise Error, "ffprobe failed for #{@video_path}: #{result.stderr}" unless result.success?

      data = JSON.parse(result.stdout)
      streams = data.fetch('streams', [])
      video_stream = streams.find { |stream| stream['codec_type'] == 'video' } || streams.first
      raise Error, "ffprobe returned no video stream for #{@video_path}" unless video_stream
      duration = video_stream['duration']&.to_f || 0

      {
        height: video_stream['height'],
        width: video_stream['width'],
        fps: parse_frame_rate(video_stream['r_frame_rate']),
        duration: duration,
        audio_stream_count: streams.count { |stream| stream['codec_type'] == 'audio' }
      }
    rescue JSON::ParserError, StandardError => e
      warn "Error extracting video metadata: #{e.message}" if @options&.dig(:debug)
      nil
    end

    def parse_frame_rate(value)
      numerator, denominator = value.to_s.split('/', 2).map(&:to_f)
      return numerator unless denominator
      return 0.0 unless denominator.positive?

      numerator / denominator
    end

    def frame_number_to_timestamp(frame_number, fps)
      seconds = (frame_number - 1) / fps.to_f
      minutes, seconds = seconds.divmod(60)
      hours, minutes = minutes.divmod(60)
      format('%02d:%02d:%06.3f', hours, minutes, seconds)
    end
  end
end
