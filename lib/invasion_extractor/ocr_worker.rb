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
      frames_dir = ensure_frames_dir
      fps = @options[:fps] || 2
      extract_progress = @options[:extract_progress_callback]
      ocr_progress = @options[:progress_callback]

      unless frames_extracted?(frames_dir)
        extract_frames(frames_dir, fps, extract_progress)
      end

      frame_paths = Dir.glob(File.join(frames_dir, '*.jpg')).sort
      total = frame_paths.length

      results = Parallel.map(frame_paths.each_with_index, in_threads: Etc.nprocessors) do |path, index|
        text = @ocr_provider.recognize(path)
        frame_number = extract_frame_number(path)
        timestamp = frame_number_to_timestamp(frame_number, fps)

        ocr_progress&.call(index + 1, total)

        Frame.new(frame_number, text, timestamp, @video_path)
      end

      results.sort_by(&:number)
    end

    private

    def ensure_frames_dir
      hash = VideoHasher.hash(@video_path)
      dir = File.join(CACHE_DIR, 'frames', hash)
      FileUtils.mkdir_p(dir)
      dir
    end

    def frames_extracted?(frames_dir)
      return false if @options[:no_cache]
      Dir.glob(File.join(frames_dir, '*.jpg')).length > 0
    end

    def extract_frames(frames_dir, fps, progress)
      crop = calculate_crop
      filter = "fps=#{fps},crop=#{crop[:width]}:#{crop[:height]}:#{crop[:x]}:#{crop[:y]}"

      hwaccel_args = ""
      if @options[:hwaccel] && GPUDetector.vaapi_available?
        hwaccel_args = GPUDetector.ffmpeg_hwaccel_args.join(' ')
        filter = "fps=#{fps},hwdownload,format=nv12,crop=#{crop[:width]}:#{crop[:height]}:#{crop[:x]}:#{crop[:y]}"
      end

      # Clean old frames first
      FileUtils.rm_f(Dir.glob(File.join(frames_dir, '*.jpg')))

      total_frames = @video_metadata && @video_metadata[:duration] > 0 ?
        (@video_metadata[:duration] * fps).to_i : 0

      threads = @options[:ffmpeg_threads] || 4
      cmd = "ffmpeg -threads #{threads} #{hwaccel_args} -i #{@video_path} -vf '#{filter}' -qscale:v 5 #{frames_dir}/frame_%06d.jpg 2>/dev/null"

      # Start ffmpeg in a separate thread
      ffmpeg_done = false
      ffmpeg_thread = Thread.new do
        system(cmd)
        ffmpeg_done = true
      end

      # Poll frame count and update progress bar
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
          # Ensure bar reaches 100%
          progress.call(total_frames, total_frames)
        end
      end

      ffmpeg_thread.join
    end

    def extract_frame_number(path)
      File.basename(path).scan(/\d+/).first.to_i
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
