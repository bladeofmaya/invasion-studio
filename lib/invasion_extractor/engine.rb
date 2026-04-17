module InvasionExtractor
  class Engine
    attr_reader :videos, :options, :session, :store, :reporter
    attr_accessor :benchmark

    # This is the main entry point for straight up processing of videos.
    def self.run!(videos, options = {})
      engine = new(videos, options)
      engine.run!
      engine
    end

    def initialize(videos, options = {})
      @options = options
      @store = SessionStore.new
      @reporter = ProgressReporter.new(options)
      @benchmark = BenchmarkRunner.new(options)

      # Initialize or load session
      initialize_session(videos)

      # Convert video paths to Video objects (only pending videos if resuming)
      @videos = build_video_list(videos)
    end

    def run!
      return self if @videos.empty?

      @benchmark.start_stage(:total)

      begin
        # Stage 1: OCR Processing
        run_ocr_stage

        # Stage 2: Scan for invasions
        run_scan_stage

        # Stage 3: Extract clips
        run_extraction_stage if @options[:command] != 'scan'

        @session.status = 'completed'
        @store.save(@session)

        @reporter.summary(
          @session.videos.length,
          @session.detected_invasions.length,
          @session.completed_clips.length,
          @benchmark.stats[:total_time]
        )

      rescue Interrupt
        @reporter.log("\nInterrupted! Saving session state...")
        @session.status = 'interrupted'
        @store.save(@session)
        raise
      rescue StandardError => e
        @session.status = 'error'
        @store.save(@session)
        raise
      ensure
        @benchmark.end_stage(:total)
        @benchmark.print_report
        @benchmark.save_report
      end

      self
    end

    def clips
      @clips ||= generate_clips
    end

    def extract_invasion_clips!(prefix = 'invasion', output_dir = 'invasion_clips', &block)
      FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

      clips.each_with_index do |clip, index|
        output_file = File.join(output_dir, format("#{prefix}_%05d.mp4", index + 1))
        clip.write(output_file) unless clip.file_exists?(output_file)
      end
    end

    # Show session status
    def show_status
      @reporter.session_summary(@session)
    end

    private

    def initialize_session(videos)
      if @options[:resume]
        # Resume existing session
        @session = @store.load(@options[:resume])
        unless @session
          raise "Session '#{@options[:resume]}' not found. Use 'bin/invasion_extractor status' to list sessions."
        end

        # Add any new videos that weren't in the original session
        existing_paths = @session.videos.map { |v| v[:path] }
        new_videos = videos.reject { |v| existing_paths.include?(v) }
        new_videos.each { |v| @session.add_video(v) }

        @session.status = 'resuming'
      else
        # Create new session
        session_id = @options[:save_session] || generate_session_id
        @session = Session.new(session_id, @options)
        videos.each { |v| @session.add_video(v) }
        @session.status = 'initialized'
      end

      @store.save(@session)
    end

    def build_video_list(all_videos)
      if @options[:resume]
        # Only process pending or errored videos when resuming
        pending_paths = @session.pending_videos.map { |v| v[:path] }
        all_videos.select { |v| pending_paths.include?(v) }.map do |video_file|
          Video.new(video_file, @options)
        end
      else
        all_videos.map { |video_file| Video.new(video_file, @options) }
      end
    end

    def run_ocr_stage
      total_videos = @videos.length
      return if total_videos == 0

      @reporter.start_stage(:ocr, total_videos)
      @benchmark.start_stage(:ocr)

      total_frames_processed = 0

      @videos.each_with_index do |video, index|
        video_path = video.video
        @reporter.log("Processing: #{File.basename(video_path)}")

        @session.update_video_status(video_path, status: 'processing')
        @store.save(@session)

        begin
          # Check if we have cached OCR data
          if video.cached_data_exists? && !@options[:no_cache]
            @reporter.log("  Using cached OCR data")
            @session.update_video_status(video_path, ocr_cache_hit: true)
          else
            @reporter.log("  Running OCR (this may take a while)...")
            @session.update_video_status(video_path, ocr_cache_hit: false)
          end

          # Get frames (this triggers OCR if needed)
          frames = video.frames

          total_frames_processed += frames.length
          @session.update_video_status(video_path,
            status: 'completed',
            frames_processed: frames.length,
            frames_total: frames.length
          )
          @store.save(@session)

          @reporter.update(index + 1, total_videos, "#{File.basename(video_path)} - #{frames.length} frames")

        rescue StandardError => e
          @session.update_video_status(video_path, status: 'error', error: e.message)
          @store.save(@session)
          @reporter.log("  Error processing #{video_path}: #{e.message}")
          raise unless @options[:continue_on_error]
        end
      end

      @reporter.complete_stage("#{total_frames_processed} frames processed across #{total_videos} videos")
      stage_time = @benchmark.end_stage(:ocr, { frames_processed: total_frames_processed })
      @benchmark.record_ocr_stats(total_frames_processed, stage_time || 0)
    end

    def run_scan_stage
      @reporter.start_stage(:scan)
      @benchmark.start_stage(:scan)

      # Build list of all frames from all videos
      all_videos = @session.videos.map { |v| Video.new(v[:path], @options) }
      scanner = Scanner.new(all_videos)

      # Record detected invasions in session
      scanner.invasion_segments.each_with_index do |segment, index|
        @session.add_invasion(
          segment.start_time,
          segment.end_time,
          segment.start_video,
          segment.end_video
        )

        # Update invasion counts on videos (accumulate)
        @session.update_video_status(segment.start_video) do |video|
          video[:invasions_detected] = (video[:invasions_detected] || 0) + 1
        end
        
        if segment.end_video != segment.start_video
          @session.update_video_status(segment.end_video) do |video|
            video[:invasions_detected] = (video[:invasions_detected] || 0) + 1
          end
        end
      end

      # Build clip queue
      scanner.invasion_segments.each_with_index do |segment, index|
        output_file = File.join(
          @options[:outdir] || 'invasion_clips',
          format("#{@options[:prefix] || 'invasion'}_%05d.mp4", index + 1)
        )
        @session.add_clip(index, output_file)
      end

      @store.save(@session)

      invasion_count = @session.detected_invasions.length
      @reporter.complete_stage("#{invasion_count} invasions detected")
      @benchmark.end_stage(:scan, { invasions_found: invasion_count })
      @benchmark.record_scan_stats(invasion_count)
    end

    def run_extraction_stage
      clips_to_extract = @session.pending_clips
      return if clips_to_extract.empty?

      total_clips = clips_to_extract.length
      @reporter.start_stage(:extraction, total_clips)
      @benchmark.start_stage(:extraction)

      # Create output directory
      FileUtils.mkdir_p(@options[:outdir] || 'invasion_clips')

      # Rebuild all videos for clip generation
      all_videos = @session.videos.map { |v| Video.new(v[:path], @options) }
      scanner = Scanner.new(all_videos)
      clip_objects = scanner.invasion_segments.map { |segment| Clip.new(segment) }

      clips_extracted = 0

      clips_to_extract.each_with_index do |clip_info, index|
        invasion_index = clip_info[:invasion_index]
        output_file = clip_info[:output_file]

        @reporter.update(index + 1, total_clips, "Extracting #{File.basename(output_file)}")

        begin
          clip = clip_objects[invasion_index]

          if clip.file_exists?(output_file)
            @reporter.log("  Skipping #{File.basename(output_file)} (already exists)")
          else
            clip.write(output_file)
          end

          @session.update_clip_status(invasion_index, 'completed')
          clips_extracted += 1

          # Update video clip counts (accumulate)
          segment = scanner.invasion_segments[invasion_index]
          @session.update_video_status(segment.start_video) do |video|
            video[:clips_extracted] = (video[:clips_extracted] || 0) + 1
          end

        rescue StandardError => e
          @reporter.log("  Error extracting clip #{invasion_index + 1}: #{e.message}")
          @session.update_clip_status(invasion_index, 'error')
          raise unless @options[:continue_on_error]
        end

        @store.save(@session)
      end

      @reporter.complete_stage("#{clips_extracted} clips extracted")
      stage_time = @benchmark.end_stage(:extraction, { clips_extracted: clips_extracted })
      @benchmark.record_extraction_stats(clips_extracted, stage_time || 0)
    end

    def generate_clips
      scanner = Scanner.new(@videos)
      scanner.invasion_segments.map do |segment|
        Clip.new(segment)
      end
    end

    def generate_session_id
      timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
      random = (0...4).map { ('a'..'z').to_a[rand(26)] }.join
      "#{timestamp}-#{random}"
    end
  end
end
