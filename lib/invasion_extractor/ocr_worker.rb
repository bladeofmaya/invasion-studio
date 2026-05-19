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
      crop = calculate_crop
      frame_size = crop[:width] * crop[:height]
      fps = @options[:fps] || 2

      frames = []
      mutex = Mutex.new
      queue = SizedQueue.new(Etc.nprocessors * 2)

      producer = Thread.new do
        cmd = build_ffmpeg_command(crop, fps)
        IO.popen(cmd, 'rb') do |io|
          frame_number = 0
          while (data = io.read(frame_size))
            break if data.bytesize < frame_size
            frame_number += 1
            queue << {
              number: frame_number,
              data: data.dup,
              timestamp: frame_number_to_timestamp(frame_number, fps)
            }
          end
        end
        queue.close
      end

      consumers = Etc.nprocessors.times.map do
        Thread.new do
          while (item = queue.pop)
            text = recognize_frame(item[:data], crop[:width], crop[:height])
            frame = Frame.new(item[:number], text, item[:timestamp], @video_path)
            mutex.synchronize { frames << frame }
          end
        end
      end

      producer.join
      consumers.each(&:join)

      frames.sort_by(&:number)
    end

    private

    def recognize_frame(data, width, height)
      tmp = Tempfile.new(['frame', '.pgm'])
      tmp.binmode
      tmp.write("P5\n#{width} #{height}\n255\n")
      tmp.write(data)
      tmp.close

      @ocr_provider.recognize(tmp.path)
    ensure
      tmp&.close
      tmp&.unlink
    end

    def build_ffmpeg_command(crop, fps)
      filter = "fps=#{fps},crop=#{crop[:width]}:#{crop[:height]}:#{crop[:x]}:#{crop[:y]},format=gray"
      "ffmpeg -i #{@video_path} -vf '#{filter}' -f rawvideo -pix_fmt gray8 pipe:1 2>/dev/null"
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
        width: (base_crop_width * scale_factor).to_i,
        height: (base_crop_height * scale_factor).to_i,
        x: (base_crop_x * scale_factor).to_i,
        y: (base_crop_y * scale_factor).to_i
      }
    end

    def get_metadata
      command = "ffprobe -v quiet -print_format json -show_streams -select_streams v:0 #{@video_path}"
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

    def frame_number_to_timestamp(frame_number, fps)
      seconds = (frame_number - 1) / fps.to_f
      minutes, seconds = seconds.divmod(60)
      hours, minutes = minutes.divmod(60)
      format('%02d:%02d:%06.3f', hours, minutes, seconds)
    end
  end
end
