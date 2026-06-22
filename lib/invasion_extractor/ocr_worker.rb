module InvasionExtractor
  class OCRWorker
    attr_reader :video_path, :video_metadata

    def initialize(video_path, ocr_provider = nil, options = {})
      @video_path = video_path
      @video_metadata = get_metadata
      @ocr_provider = ocr_provider || InvasionExtractor::OCR::TesseractProvider.new
      @options = options
    end

    def run!
      fps = @options[:fps] || 1
      extract_progress = @options[:extract_progress_callback]

      Dir.mktmpdir do |frames_dir|
        ffmpeg_thread = extract_frames(frames_dir, fps, extract_progress)
        results = run_ocr_pipeline(frames_dir, fps, ffmpeg_thread)
        ffmpeg_thread.join
        results.sort_by(&:number)
      end
    end

    private

    def run_ocr_pipeline(frames_dir, fps, ffmpeg_thread)
      queue = Queue.new
      results = []
      mutex = Mutex.new
      total_frames = estimated_total_frames(fps)

      # ponytail: manual thread pool instead of Parallel gem; tesseract shell-out
      # releases the GIL, so threads parallelize nearly as well as processes
      # without fork overhead. ceiling: GIL contention on pure Ruby work.
      workers = Etc.nprocessors.times.map do
        Thread.new do
          loop do
            item = queue.pop
            break if item == :done

            path, _index = item
            text = @ocr_provider.recognize(path)
            frame_number = extract_frame_number(path)
            timestamp = frame_number_to_timestamp(frame_number, fps)

            mutex.synchronize do
              results << Frame.new(frame_number, text, timestamp, @video_path)
              @ocr_progress += 1 if @options[:progress_callback]
            end
          end
        end
      end

      @ocr_progress = 0 if @options[:progress_callback]

      monitor = if @options[:progress_callback] && total_frames > 0
        Thread.new do
          loop do
            @options[:progress_callback].call(@ocr_progress, total_frames)
            break if @ocr_progress >= total_frames
            sleep 0.3
          end
        end
      end

      last_count = 0
      loop do
        frame_paths = Dir.glob(File.join(frames_dir, '*.jpg')).sort
        new_paths = frame_paths[last_count..]
        new_paths.each do |path|
          queue << [path, last_count]
          last_count += 1
        end

        break if !ffmpeg_thread.alive? && last_count >= frame_paths.length
        sleep 0.1 if new_paths.empty?
      end

      workers.each { queue << :done }
      workers.each(&:join)
      monitor&.join

      results
    end

    def extract_frames(frames_dir, fps, progress)
      crop = calculate_crop
      filter = "fps=#{fps},crop=#{crop[:width]}:#{crop[:height]}:#{crop[:x]}:#{crop[:y]}"

      hwaccel_args = ""
      if @options[:hwaccel] && GPUDetector.vaapi_available?
        hwaccel_args = GPUDetector.ffmpeg_hwaccel_args.join(' ')
        filter = "fps=#{fps},hwdownload,format=nv12,crop=#{crop[:width]}:#{crop[:height]}:#{crop[:x]}:#{crop[:y]}"
      end

      total_frames = estimated_total_frames(fps)

      threads = @options[:ffmpeg_threads] || 4
      cmd = "ffmpeg -threads #{threads} #{hwaccel_args} -i #{@video_path} -vf '#{filter}' -qscale:v 5 #{frames_dir}/frame_%06d.jpg 2>/dev/null"

      ffmpeg_done = false
      ffmpeg_thread = Thread.new do
        system(cmd)
        ffmpeg_done = true
      end

      if progress && total_frames > 0
        Thread.new do
          last_count = 0
          until ffmpeg_done
            sleep 0.5
            count = Dir.glob(File.join(frames_dir, '*.jpg')).length
            if count > last_count
              progress.call(count, total_frames)
              last_count = count
            end
          end
          progress.call(total_frames, total_frames)
        end
      end

      ffmpeg_thread
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
      command = "ffprobe -v quiet -print_format json -show_streams -select_streams v:0 #{@video_path}"
      output = `#{command}`
      data = JSON.parse(output)
      video_stream = data['streams'][0]
      duration = video_stream['duration']&.to_f || 0

      {
        height: video_stream['height'],
        width: video_stream['width'],
        fps: eval(video_stream['r_frame_rate']).to_i,
        duration: duration
      }
    rescue JSON::ParserError, StandardError => e
      puts "Error extracting video metadata: #{e.message}"
      nil
    end

    def frame_number_to_timestamp(frame_number, fps)
      seconds = (frame_number - 1) / fps.to_f
      minutes, seconds = seconds.divmod(60)
      hours, minutes = minutes.divmod(60)
      format('%02d:%02d:%06.3f', hours, minutes, seconds)
    end
  end
end
