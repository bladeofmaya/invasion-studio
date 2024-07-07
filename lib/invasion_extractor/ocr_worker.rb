#
# This class processes the video and returns a list of
# InvasionExtractor::Frame objects.
#
module InvasionExtractor
  class OCRWorker
    attr_reader :video, :video_metadata

    def initialize(video)
      @video = video
      @video_metadata = get_metadata
      @tmpdir = File.join(Dir.tmpdir, "invasion_extractor_ocr_worker_#{Time.now.to_i}")
      FileUtils.mkdir_p(@tmpdir)
    end

    def run!
      frames = generate_image_frames

      all_frame_data = Parallel.map(frames.each_with_index, in_processes: Etc.nprocessors) do |frame_path, index|
        puts "Processing frame #{index + 1} of #{frames.length}"
        frame_number = extract_frame_number(frame_path)
        frame_text = RTesseract.new(frame_path).to_s
        frame_timestamp = frame_number_to_timestamp(frame_number)
        video_file = @video
        InvasionExtractor::Frame.new(frame_number, frame_text, frame_timestamp, video_file)
      end

      cleanup
      return all_frame_data
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
      base_width = 2560
      base_height = 1440
      base_crop_width = 700
      base_crop_height = 150
      base_crop_x = 950
      base_crop_y = 965

      scale_factor = @video_metadata[:height].to_f / base_height

      crop_width = (base_crop_width * scale_factor).to_i
      crop_height = (base_crop_height * scale_factor).to_i
      crop_x = (base_crop_x * scale_factor).to_i
      crop_y = (base_crop_y * scale_factor).to_i

      # TODO: Make this failsafe for different operating systems
      system("ffmpeg -c:v hevc -threads 12 -i #{@video} -r 2 -filter_complex 'crop=#{crop_width}:#{crop_height}:#{crop_x}:#{crop_y},eq=contrast=10:brightness=1.0[out]' -map '[out]' -qscale:v 2 -preset ultrafast #{@tmpdir}/frame_%04d.jpg")

      Dir.glob("#{@tmpdir}/*.jpg").sort
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
      seconds = (frame_number - 1) / 2.0  # Assuming 2 fps
      minutes, seconds = seconds.divmod(60)
      hours, minutes = minutes.divmod(60)
      format("%02d:%02d:%06.3f", hours, minutes, seconds)
    end

    def cleanup
      FileUtils.rm_rf(@tmpdir)
    end
  end
end
