module InvasionExtractor
  # Handles progress reporting with visual progress bars
  class ProgressReporter
    BAR_WIDTH = 40

    attr_reader :enabled, :quiet

    def initialize(options = {})
      @enabled = !options[:no_progress]
      @quiet = options[:quiet]
      @current_stage = nil
      @stage_start_time = nil
    end

    def start_stage(stage_name, total_items = nil)
      return unless @enabled

      @current_stage = stage_name
      @stage_start_time = Time.now
      @stage_total = total_items
      @stage_current = 0

      print_stage_header(stage_name, total_items)
    end

    def update(current, total, message = nil)
      return unless @enabled

      @stage_current = current
      @stage_total = total

      progress_bar = build_progress_bar(current, total)
      percentage = total > 0 ? ((current.to_f / total) * 100).round(1) : 0
      eta = calculate_eta(current, total)

      line = "\r#{progress_bar} #{percentage}%"
      line += " | ETA: #{eta}" if eta && current < total
      line += " | #{message}" if message

      print line.ljust(80) # Pad to clear previous lines
      $stdout.flush
    end

    def update_video(video_path, current_frame, total_frames)
      return unless @enabled

      video_name = File.basename(video_path)
      progress_bar = build_progress_bar(current_frame, total_frames)
      percentage = total_frames > 0 ? ((current_frame.to_f / total_frames) * 100).round(1) : 0
      eta = calculate_eta(current_frame, total_frames)

      line = "\r[#{video_name}] #{progress_bar} #{percentage}%"
      line += " | ETA: #{eta}" if eta && current_frame < total_frames

      print line.ljust(80)
      $stdout.flush
    end

    def complete_stage(message = nil)
      return unless @enabled

      duration = Time.now - @stage_start_time if @stage_start_time
      puts "\r#{build_progress_bar(@stage_total, @stage_total)} 100% ✓".ljust(80)
      puts "  Completed in #{format_duration(duration)}" if duration && !@quiet
      puts "  #{message}" if message && !@quiet
      @current_stage = nil
    end

    def log(message)
      return if @quiet

      # Clear current line and print message
      print "\r" + " " * 80 + "\r" if @enabled
      puts message

      # Redraw progress bar if we're in a stage
      update(@stage_current, @stage_total) if @enabled && @current_stage && @stage_total
    end

    def summary(videos_processed, invasions_found, clips_extracted, total_time)
      return if @quiet

      puts "\n" + "=" * 60
      puts "PROCESSING COMPLETE"
      puts "=" * 60
      puts "Videos Processed: #{videos_processed}"
      puts "Invasions Found:  #{invasions_found}"
      puts "Clips Extracted:  #{clips_extracted}"
      puts "Total Time:       #{format_duration(total_time)}"
      puts "=" * 60
    end

    def session_summary(session)
      return if @quiet

      puts "\n" + "=" * 60
      puts "SESSION STATUS: #{session.session_id}"
      puts "=" * 60
      puts "Created: #{session.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "Updated: #{session.updated_at.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "Status:  #{session.status}"
      puts "\nVideos:"
      session.videos.each do |video|
        status_icon = case video[:status]
                      when 'completed' then '✓'
                      when 'processing' then '▶'
                      when 'error' then '✗'
                      else '○'
                      end
        path = video[:path] || 'unknown'
        puts "  #{status_icon} #{File.basename(path)}"
        puts "     Status: #{video[:status]}, Frames: #{video[:frames_processed]}/#{video[:frames_total]}"
        if video[:invasions_detected] && video[:invasions_detected] > 0
          puts "     Invasions: #{video[:invasions_detected]}"
        end
      end

      if session.detected_invasions.any?
        puts "\nDetected Invasions: #{session.detected_invasions.length}"
        session.detected_invasions.each_with_index do |invasion, idx|
          display_idx = (invasion[:index] || idx) + 1
          puts "  [#{display_idx}] #{invasion[:start_time]} → #{invasion[:end_time]}"
        end
      end

      if session.clips_to_extract.any?
        completed = session.completed_clips.length
        pending = session.pending_clips.length
        puts "\nClips: #{completed}/#{session.clips_to_extract.length} extracted"
      end

      puts "=" * 60
    end

    private

    def print_stage_header(stage_name, total_items)
      stage_description = case stage_name
                          when :ocr then "OCR Processing"
                          when :scan then "Scanning for Invasions"
                          when :extraction then "Extracting Clips"
                          when :resume then "Resuming Session"
                          else stage_name.to_s.gsub('_', ' ').capitalize
                          end

      puts "\n#{stage_description}#{total_items ? " (#{total_items} items)" : ''}:"
    end

    def build_progress_bar(current, total)
      return "[" + "=" * BAR_WIDTH + "]" if total.nil? || total == 0

      filled = ((current.to_f / total) * BAR_WIDTH).to_i
      filled = BAR_WIDTH if filled > BAR_WIDTH
      empty = BAR_WIDTH - filled

      "[" + "=" * filled + ">" * [empty, 1].min + " " * [empty - 1, 0].max + "]"
    end

    def calculate_eta(current, total)
      return nil if current == 0 || @stage_start_time.nil?

      elapsed = Time.now - @stage_start_time
      rate = current.to_f / elapsed
      remaining = total - current
      eta_seconds = remaining / rate

      format_duration(eta_seconds)
    end

    def format_duration(seconds)
      return "0s" if seconds < 1

      if seconds < 60
        "#{seconds.round(0)}s"
      elsif seconds < 3600
        "#{(seconds / 60).to_i}m #{(seconds % 60).to_i}s"
      else
        "#{(seconds / 3600).to_i}h #{((seconds % 3600) / 60).to_i}m"
      end
    end
  end
end
