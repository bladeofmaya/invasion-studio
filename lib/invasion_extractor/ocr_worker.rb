#
# This class processes the video and returns a list of
# InvasionExtractor::Frame objects.
#
module InvasionExtractor
  class OCRWorker
    attr_reader :video, :video_metadata, :ocr_provider, :frame_filter, :progress_callback

    def initialize(video, ocr_provider = nil, options = {})
      @video = video
      @video_metadata = get_metadata
      @ocr_provider = ocr_provider || InvasionExtractor::OCR::TesseractProvider.new
      @frame_filter = options[:frame_filter] || InvasionExtractor::FrameFilter.new(enabled: options[:filter_enabled] != false)
      @progress_callback = options[:progress_callback]
      @options = options
      @tmpdir = File.join(Dir.tmpdir, "invasion_extractor_ocr_worker_#{Time.now.to_i}")
      FileUtils.mkdir_p(@tmpdir)
    end

    def run!
      frames = generate_image_frames
      total_frames = frames.length

      report_progress(:extracting_frames, 0, total_frames)

      filtered_frames = frames.each_with_index.select do |frame_path, index|
        should_process = @frame_filter.should_process?(frame_path)
        report_progress(:extracting_frames, index + 1, total_frames) unless should_process
        should_process
      end

      total_to_process = filtered_frames.length
      processed_count = 0

      all_frame_data = Parallel.map(filtered_frames, in_processes: Etc.nprocessors) do |frame_path, _index|
        processed_count += 1
        report_progress(:processing_ocr, processed_count, total_to_process)

        frame_number = extract_frame_number(frame_path)
        frame_text = @ocr_provider.recognize(frame_path)
        frame_timestamp = frame_number_to_timestamp(frame_number)
        video_file = @video
        InvasionExtractor::Frame.new(frame_number, frame_text, frame_timestamp, video_file)
      end

      report_progress(:processing_ocr, total_to_process, total_to_process)
      cleanup
      all_frame_data
    end

    def filter_stats
      @frame_filter.stats
    end

    private

    # Calculates the crop dimensions based on the video's resolution and
    # extracts every second frame from the video for OCR processing.
    #
    # NOTE: 2 fps is a good balance between speed and accuracy.
    #       Additional testing is worth the time so we can find the best
    #       balance between speed and accuracy.
    #
    # Returns an array of frame paths.
    def generate_image_frames
      base_height = 1440
      base_crop_width = 700
      base_crop_height = 200 # Taller crop to capture full text box
      base_crop_x = 950
      base_crop_y = 960 # Text appears at bottom center (~67% height in 1440p)

      height = @video_metadata ? @video_metadata[:height] : base_height
      scale_factor = height.to_f / base_height

      crop_width = (base_crop_width * scale_factor).to_i
      crop_height = (base_crop_height * scale_factor).to_i
      crop_x = (base_crop_x * scale_factor).to_i
      crop_y = (base_crop_y * scale_factor).to_i

      use_gpu = @options && @options[:use_gpu] != false && InvasionExtractor::GPUDetector.available?

      if use_gpu
        generate_frames_with_gpu(crop_width, crop_height, crop_x, crop_y)
      else
        generate_frames_with_cpu(crop_width, crop_height, crop_x, crop_y)
      end

      Dir.glob("#{@tmpdir}/*.jpg").sort
    end

    def generate_frames_with_cpu(crop_width, crop_height, crop_x, crop_y)
      # TODO: Make this failsafe for different operating systems
      system("ffmpeg -threads 12 -i #{@video} -r 2 -filter_complex 'crop=#{crop_width}:#{crop_height}:#{crop_x}:#{crop_y},eq=contrast=10:brightness=1.0[out]' -map '[out]' -qscale:v 2 -preset ultrafast #{@tmpdir}/frame_%04d.jpg")
    end

    def generate_frames_with_gpu(crop_width, crop_height, crop_x, crop_y)
      hwaccel_opts = InvasionExtractor::GPUDetector.ffmpeg_hwaccel_options.join(' ')

      # GPU-accelerated decoding with CPU filtering
      # hwdownload transfers from GPU to CPU memory before filters
      cmd = "ffmpeg #{hwaccel_opts} -i #{@video} -r 2 -vf 'hwdownload,format=nv12,crop=#{crop_width}:#{crop_height}:#{crop_x}:#{crop_y},eq=contrast=10:brightness=1.0' -qscale:v 2 -preset ultrafast #{@tmpdir}/frame_%04d.jpg"
      success = system(cmd)

      # Fallback to CPU if GPU fails
      return if success

      puts 'GPU frame extraction failed, falling back to CPU...'
      generate_frames_with_cpu(crop_width, crop_height, crop_x, crop_y)
    end

    def get_metadata
      command = "ffprobe -v quiet -print_format json -show_streams -select_streams v:0 #{@video}"

      output = `#{command}`
      data = JSON.parse(output)

      video_stream = data['streams'][0]

      {
        height: video_stream['height'],
        width: video_stream['width'],
        fps: eval(video_stream['r_frame_rate']).to_i
      }
    rescue JSON::ParserError, StandardError => e
      puts "Error extracting video metadata: #{e.message}"
      nil
    end

    def extract_frame_number(path)
      File.basename(path).scan(/\d+/).first.to_i
    end

    def frame_number_to_timestamp(frame_number)
      seconds = (frame_number - 1) / 2.0 # Assuming 2 fps
      minutes, seconds = seconds.divmod(60)
      hours, minutes = minutes.divmod(60)
      format('%02d:%02d:%06.3f', hours, minutes, seconds)
    end

    def cleanup
      FileUtils.rm_rf(@tmpdir)
    end

    def report_progress(event, current, total)
      return unless @progress_callback

      @progress_callback.call(event, current, total)
    end
  end
end
