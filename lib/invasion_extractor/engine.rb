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
      @videos.each do |video|
        puts "Processing: #{File.basename(video.path)}" unless @options[:quiet]

        frames = if @options[:quiet]
          video.frames
        else
          run_ocr_with_progress(video)
        end

        puts "  #{frames.length} frames processed" unless @options[:quiet]

        if @options[:debug]
          write_debug_file(video.path, frames)
        end
      end
    end

    def run_ocr_with_progress(video)
      # Do a quick metadata pass to get frame count for the bars
      worker = OCRWorker.new(video.path)
      meta = worker.video_metadata
      fps = @options[:fps] || 1
      total_frames = meta && meta[:duration] > 0 ? (meta[:duration] * fps).to_i : 0

      extract_bar = nil
      ocr_bar = nil

      if total_frames > 0
        extract_bar = TTY::ProgressBar.new(
          "  Extracting frames [:bar] :current/:total (:percent)",
          total: total_frames,
          width: 30
        )

        ocr_bar = TTY::ProgressBar.new(
          "  OCR               [:bar] :current/:total (:percent) :elapsed ETA::eta",
          total: total_frames,
          width: 30
        )
      end

      extract_callback = proc { |current, total| extract_bar&.current = current }
      ocr_callback = proc { |current, total| ocr_bar&.current = current }

      video_with_progress = Video.new(video.path, @options.merge(
        extract_progress_callback: extract_callback,
        progress_callback: ocr_callback
      ))
      video_with_progress.frames
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

      start_index = find_highest_clip_number(outdir, prefix)

      puts "Extracting clips..." unless @options[:quiet]
      puts "  Starting from #{prefix}_#{format('%05d', start_index + 1)}" unless @options[:quiet] || start_index == 0

      segs.each_with_index do |segment, index|
        output_file = File.join(outdir, format("#{prefix}_%05d.mp4", start_index + index + 1))
        clip = Clip.new(segment, @options)

        if clip.file_exists?(output_file)
          puts "  Skipping #{File.basename(output_file)} (already exists)" unless @options[:quiet]
        else
          clip.write(output_file)
          puts "  Extracted #{File.basename(output_file)}" unless @options[:quiet]
        end
      end

      puts "  #{segs.length} clips extracted" unless @options[:quiet]
    end

    def find_highest_clip_number(outdir, prefix)
      return 0 unless Dir.exist?(outdir)

      pattern = /^#{Regexp.escape(prefix)}_(\d{5})\.mp4$/
      existing_numbers = Dir.entries(outdir).map do |entry|
        match = entry.match(pattern)
        match ? match[1].to_i : nil
      end.compact

      existing_numbers.empty? ? 0 : existing_numbers.max
    end

    def write_debug_file(video_path, frames)
      debug_file = "#{VideoHasher.hash(video_path)}.debug.yml"
      data = frames.map { |f| { timestamp: f.timestamp, text: f.text } }
      File.write(debug_file, data.to_yaml)
      puts "  Debug written to: #{debug_file}" unless @options[:quiet]
    end
  end
end
