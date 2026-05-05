require 'ruby-progressbar'

module InvasionExtractor
  # Handles progress reporting with visual progress bars using ruby-progressbar
  class ProgressReporter
    attr_reader :enabled, :quiet

    def initialize(options = {})
      @enabled = !options[:no_progress]
      @quiet = options[:quiet]
      @debug = options[:debug]
      @current_bar = nil
      @bars = []
    end

    def start_stage(stage_name, total_items = nil)
      return unless @enabled

      finish_current_bar if @current_bar

      title = stage_title(stage_name)

      if total_items && total_items > 0
        @current_bar = ProgressBar.create(
          title: title,
          total: total_items,
          format: '%t: |%B| %c/%u %p%% %e',
          progress_mark: '█',
          remainder_mark: '░',
          throttle_rate: 0.1,
          output: $stderr,
          length: 60
        )
      else
        # Indeterminate progress (spinner style)
        @current_bar = ProgressBar.create(
          title: title,
          total: nil,
          format: '%t %a %e',
          output: $stderr
        )
      end

      @bars << @current_bar
    end

    def update(current, total = nil, message = nil)
      return unless @enabled && @current_bar

      if total && @current_bar.total != total
        @current_bar.total = total
      end

      @current_bar.progress = current if current

      if message && @current_bar.total
        # Update format with message
        @current_bar.format("%t (#{message}): |%B| %c/%C %p%% %e")
      end
    end

    def update_video(video_path, current_frame, total_frames)
      return unless @enabled && @current_bar

      video_name = File.basename(video_path)
      @current_bar.format("#{video_name}: |%B| %c/%C %p%% %e") if @current_bar.total
      @current_bar.total = total_frames if @current_bar.total != total_frames
      @current_bar.progress = current_frame
    end

    def increment(amount = 1)
      return unless @enabled && @current_bar

      @current_bar.progress += amount
    end

    def complete_stage(message = nil)
      return unless @enabled && @current_bar

      if message && !@quiet
        @current_bar.finish
        $stderr.puts "  #{message}"
      else
        @current_bar.finish
      end

      @current_bar = nil
    end

    def log(message)
      return if @quiet

      if @current_bar && @enabled
        $stderr.puts "\n#{message}"
      else
        puts message
      end
    end

    def summary(videos_processed, invasions_found, clips_extracted, total_time)
      return if @quiet

      finish_all_bars

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

      finish_all_bars

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

    def finish_current_bar
      @current_bar&.finish
      @current_bar = nil
    end

    def finish_all_bars
      @bars.each(&:finish)
      @bars.clear
      @current_bar = nil
    end

    def stage_title(stage_name)
      case stage_name
      when :ocr then 'OCR Processing'
      when :scan then 'Scanning for Invasions'
      when :extraction then 'Extracting Clips'
      when :resume then 'Resuming Session'
      else stage_name.to_s.gsub('_', ' ').capitalize
      end
    end

    def format_duration(seconds)
      return "0s" if seconds.nil? || seconds < 1

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
