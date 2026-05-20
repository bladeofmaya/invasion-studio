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
      if @options[:quiet]
        @videos.each do |video|
          frames = video.frames
          write_debug_file(video.path, frames) if @options[:debug]
        end
        return
      end

      if @videos.length == 1
        single_video_bar = TTY::ProgressBar.new(
          "OCR [:bar] :current/:total (:percent) :elapsed ETA::eta",
          total: @videos.first.total_frames,
          width: 30
        )
        process_video_with_progress(@videos.first, single_video_bar)
        single_video_bar.finish
      else
        multi_bar = TTY::ProgressBar::Multi.new(
          "OCR [:bar] :current/:total (:percent) :elapsed",
          width: 30
        )

        bars = {}
        @videos.each do |video|
          bars[video.path] = multi_bar.register(
            "  #{File.basename(video.path)} [:bar] :current/:total (:percent)",
            total: video.total_frames,
            width: 20
          )
        end

        multi_bar.start

        # Use threads so bars can be shared safely
        Parallel.each(@videos, in_threads: [4, @videos.length].min) do |video|
          bar = bars[video.path]
          process_video_with_progress(video, bar)
        end

        multi_bar.finish
      end
    end

    def process_video_with_progress(video, bar)
      callback = proc { |current, total| bar&.current = [current, total].min }
      video_options = video.options.merge(progress_callback: callback)
      video_with_callback = Video.new(video.path, video_options)
      frames = video_with_callback.frames

      if @options[:debug]
        write_debug_file(video.path, frames)
      end
    end

    def run_scan_stage
      puts "Scanning for invasions..." unless @options[:quiet]
      segs = scanner.invasion_segments

      if @options[:debug]
        debug_matches = scanner.matched_frames
        puts "  Matched #{debug_matches.length} frames:"
        debug_matches.each do |f|
          match_type = f.text.match?(Scanner::START_REGEX) ? 'START' : 'END'
          puts "    [#{match_type}] #{f.timestamp} => #{f.text.inspect}"
        end
      end

      puts "  #{segs.length} invasions detected" unless @options[:quiet]
    end

    def run_extraction_stage
      segs = scanner.invasion_segments
      return if segs.empty?

      outdir = @options[:outdir] || 'invasion_clips'
      prefix = @options[:prefix] || 'invasion'
      FileUtils.mkdir_p(outdir)

      unless @options[:quiet]
        extract_bar = TTY::ProgressBar.new(
          "Extracting clips [:bar] :current/:total (:percent)",
          total: segs.length,
          width: 30
        )
      end

      Parallel.each(segs.each_with_index.to_a, in_threads: [4, segs.length].min) do |segment, index|
        output_file = File.join(outdir, format("#{prefix}_%05d.mp4", index + 1))
        clip = Clip.new(segment, @options)

        if clip.file_exists?(output_file)
          puts "  Skipping #{File.basename(output_file)} (already exists)" unless @options[:quiet]
        else
          clip.write(output_file)
          puts "  Extracted #{File.basename(output_file)}" unless @options[:quiet]
        end

        extract_bar&.advance
      end

      puts "  #{segs.length} clips extracted" unless @options[:quiet]
    end

    def write_debug_file(video_path, frames)
      debug_file = "#{VideoHasher.hash(video_path)}.debug.yml"
      data = frames.map { |f| { timestamp: f.timestamp, text: f.text } }
      File.write(debug_file, data.to_yaml)
      puts "  Debug written to: #{debug_file}" unless @options[:quiet]
    end
  end
end
