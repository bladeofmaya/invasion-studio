module InvasionExtractor
  # Manages session state for resume capability
  class Session
    attr_accessor :session_id, :created_at, :videos, :detected_invasions, 
                  :clips_to_extract, :status, :options, :updated_at

    def initialize(session_id, options = {})
      @session_id = session_id
      @created_at = Time.now
      @updated_at = Time.now
      @options = options
      @videos = []
      @detected_invasions = []
      @clips_to_extract = []
      @status = 'initialized'
    end

    def add_video(path)
      @videos << {
        path: path,
        status: 'pending',
        ocr_cache_hit: false,
        invasions_detected: 0,
        clips_extracted: 0,
        frames_processed: 0,
        frames_total: 0,
        error: nil
      }
    end

    def update_video_status(path, updates = {}, &block)
      video = @videos.find { |v| v[:path] == path }
      return unless video

      updates.each do |key, value|
        video[key] = value
      end

      # Allow block form for custom updates (e.g., incrementing counters)
      block.call(video) if block_given?

      touch
    end

    def add_invasion(start_time, end_time, start_video, end_video)
      @detected_invasions << {
        index: @detected_invasions.length,
        start_time: start_time,
        end_time: end_time,
        start_video: start_video,
        end_video: end_video
      }
      touch
    end

    def add_clip(invasion_index, output_file)
      @clips_to_extract << {
        invasion_index: invasion_index,
        output_file: output_file,
        status: 'pending'
      }
      touch
    end

    def update_clip_status(invasion_index, status)
      clip = @clips_to_extract.find { |c| c[:invasion_index] == invasion_index }
      return unless clip

      clip[:status] = status
      touch
    end

    def completed_videos
      @videos.select { |v| v[:status] == 'completed' }
    end

    def pending_videos
      @videos.select { |v| v[:status] == 'pending' || v[:status] == 'processing' }
    end

    def completed_clips
      @clips_to_extract.select { |c| c[:status] == 'completed' }
    end

    def pending_clips
      @clips_to_extract.select { |c| c[:status] == 'pending' }
    end

    def to_h
      {
        session_id: @session_id,
        created_at: @created_at.iso8601,
        updated_at: @updated_at.iso8601,
        status: @status,
        options: @options,
        videos: @videos,
        detected_invasions: @detected_invasions,
        clips_to_extract: @clips_to_extract
      }
    end

    def self.from_h(data)
      # Helper to recursively symbolize keys
      symbolize = ->(obj) {
        case obj
        when Hash
          obj.transform_keys(&:to_sym).transform_values { |v| symbolize.call(v) }
        when Array
          obj.map { |item| symbolize.call(item) }
        else
          obj
        end
      }

      data = symbolize.call(data)

      session = new(data[:session_id])
      session.created_at = Time.parse(data[:created_at]) if data[:created_at]
      session.updated_at = Time.parse(data[:updated_at]) if data[:updated_at]
      session.status = data[:status]
      session.options = data[:options] || {}
      session.videos = data[:videos] || []
      session.detected_invasions = data[:detected_invasions] || []
      session.clips_to_extract = data[:clips_to_extract] || []
      session
    end

    private

    def touch
      @updated_at = Time.now
    end
  end
end
