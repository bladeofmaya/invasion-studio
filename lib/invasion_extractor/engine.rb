module InvasionExtractor
  class Engine
    attr_reader :videos, :options

    def self.run!(videos, options = {})
      engine = new(videos, options)
      engine.run!
      engine
    end

    def initialize(videos, options = {})
      @options = options
      @videos = videos.map { |v| Video.new(v, @options) }
    end

    def run!
      return self if @videos.empty?

      run_ocr_stage
      run_scan_stage
      run_extraction_stage if @options[:command] != 'scan'

      self
    end

    def clips
      scanner.invasion_segments.map { |segment| Clip.new(segment, @options) }
    end

    def scanner
      @scanner ||= Scanner.new(@videos)
    end

    private

    def run_ocr_stage
      Parallel.each(@videos, in_processes: [4, @videos.length].min) do |video|
        puts "Processing: #{File.basename(video.path)}"
        frames = video.frames
        puts "  #{frames.length} frames processed"

        if @options[:debug]
          write_debug_file(video.path, frames)
        end
      end
    end

    def run_scan_stage
      puts "Scanning for invasions..."
      segs = scanner.invasion_segments

      if @options[:debug]
        debug_matches = scanner.matched_frames
        puts "  Matched #{debug_matches.length} frames:"
        debug_matches.each do |f|
          match_type = f.text.match?(Scanner::START_REGEX) ? 'START' : 'END'
          puts "    [#{match_type}] #{f.timestamp} => #{f.text.inspect}"
        end
      end

      puts "  #{segs.length} invasions detected"
    end

    def run_extraction_stage
      segs = scanner.invasion_segments
      return if segs.empty?

      outdir = @options[:outdir] || 'invasion_clips'
      prefix = @options[:prefix] || 'invasion'
      FileUtils.mkdir_p(outdir)

      puts "Extracting clips..."
      segs.each_with_index do |segment, index|
        output_file = File.join(outdir, format("#{prefix}_%05d.mp4", index + 1))
        clip = Clip.new(segment, @options)

        if clip.file_exists?(output_file)
          puts "  Skipping #{File.basename(output_file)} (already exists)"
        else
          clip.write(output_file)
          puts "  Extracted #{File.basename(output_file)}"
        end
      end

      puts "  #{segs.length} clips extracted"
    end

    def write_debug_file(video_path, frames)
      debug_file = "#{VideoHasher.hash(video_path)}.debug.yml"
      data = frames.map { |f| { timestamp: f.timestamp, text: f.text } }
      File.write(debug_file, data.to_yaml)
      puts "  Debug written to: #{debug_file}"
    end
  end
end
