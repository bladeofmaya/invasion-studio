module InvasionExtractor
  class Scanner

    Segment = Struct.new(:start_time, :start_video, :end_time, :end_video)

    START_REGEX = /Defeat.*Host of Fingers!/i
    END_REGEX = /Returning to your world/i

    attr_reader :invasion_segments

    def initialize(videos)
      @videos = videos
      @invasion_segments = generate_invasion_segments
    end

    def all_frames
      @videos.flat_map(&:frames)
    end

    private

    def generate_invasion_segments
      relevant_frames = filter_relevant_frames
      return [] if relevant_frames.empty?

      segments = []
      start_frame = nil

      # Handle case where first frame is an end frame
      if relevant_frames.first.text.match?(END_REGEX)
        start_frame = OpenStruct.new(timestamp: "00:00:00", video_file: relevant_frames.first.video_file)
      end

      relevant_frames.each do |frame|
        if frame.text.match?(START_REGEX)
          start_frame = frame
        elsif frame.text.match?(END_REGEX) && start_frame
          segments << Segment.new(
            start_frame.timestamp,
            start_frame.video_file,
            frame.timestamp,
            frame.video_file
          )
          start_frame = nil
        end
      end

      # Handle case where last frame is a start frame
      if start_frame
        end_frame = OpenStruct.new(timestamp: last_frame_timestamp, video_file: start_frame.video_file)
        segments << Segment.new(
          start_frame.timestamp,
          start_frame.video_file,
          end_frame.timestamp,
          end_frame.video_file
        )
      end
      segments
    end

    def filter_relevant_frames
      all_frames.select { |frame| frame.text.match?(START_REGEX) || frame.text.match?(END_REGEX) }
    end

    def last_frame_timestamp
      all_frames.last.timestamp
    end
  end
end
