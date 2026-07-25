module InvasionStudio
  class Scanner
    Segment = Data.define(:start_time, :start_video, :end_time, :end_video)

    START_REGEX = /Defeat.*Host of Fingers|Commencing combat/i
    END_REGEX = /Returning to your world|Combat ends/i

    attr_reader :invasion_segments

    def initialize(videos)
      @videos = videos
      @invasion_segments = generate_invasion_segments
    end

    def matched_frames
      frames = []
      @videos.each do |video|
        video.frames.each do |frame|
          frames << frame if frame.text.match?(START_REGEX) || frame.text.match?(END_REGEX)
        end
      end
      frames
    end

    private

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
        end_frame = last_frame || start_frame
        segments << Segment.new(
          start_frame.timestamp,
          start_frame.video_path,
          end_frame.timestamp,
          end_frame.video_path
        )
      end

      segments
    end

    def last_frame
      @videos.reverse_each do |video|
        frame = video.frames.last
        return frame if frame
      end
      nil
    end
  end
end
