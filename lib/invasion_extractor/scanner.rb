module InvasionExtractor
  class Scanner
    Segment = Struct.new(:start_time, :start_video, :end_time, :end_video)

    START_REGEX = /Defeat.*Host of Fingers|Commencing combat/i
    END_REGEX = /Returning to your world|Combat ends/i

    attr_reader :invasion_segments

    def initialize(videos)
      @videos = videos
      @invasion_segments = generate_invasion_segments
    end

    def matched_frames
      all_frames.select { |frame| frame.text.match?(START_REGEX) || frame.text.match?(END_REGEX) }
    end

    private

    def all_frames
      @videos.flat_map(&:frames)
    end

    def generate_invasion_segments
      relevant_frames = matched_frames
      return [] if relevant_frames.empty?

      segments = []
      start_frame = nil

      if relevant_frames.first.text.match?(END_REGEX)
        start_frame = OpenStruct.new(timestamp: "00:00:00", video_path: relevant_frames.first.video_path)
      end

      relevant_frames.each do |frame|
        if frame.text.match?(START_REGEX)
          start_frame = frame
        elsif frame.text.match?(END_REGEX) && start_frame
          segments << Segment.new(
            start_frame.timestamp,
            start_frame.video_path,
            frame.timestamp,
            frame.video_path
          )
          start_frame = nil
        end
      end

      if start_frame
        end_frame = OpenStruct.new(timestamp: last_frame_timestamp, video_path: start_frame.video_path)
        segments << Segment.new(
          start_frame.timestamp,
          start_frame.video_path,
          end_frame.timestamp,
          end_frame.video_path
        )
      end

      segments
    end

    def last_frame_timestamp
      all_frames.last.timestamp
    end
  end
end
