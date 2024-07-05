module InvasionCutter
  class InvasionScanner
    InvasionSegment = Struct.new(:start_time, :start_video, :end_time, :end_video)

    attr_reader :invasion_segments

    def initialize(videos)
      @videos = videos
      @invasion_segments = generate_invasion_segments
    end

    private

    def all_frames
      @videos.flat_map(&:frame_data)
    end

    def start_and_end_frames
      frames = all_frames.select do |frame|
        frame.text.match?(/Defeat.*Host of Fingers!/i) ||
        frame.text.match?(/Returning to your world/i)
      end

      result = []
      current_type = nil

      frames.each do |frame|
        is_start = frame.text.match?(/Defeat.*Host of Fingers!/i)
        is_end = frame.text.match?(/Returning to your world/i)

        frame_type = is_start ? :start : :end

        if frame_type != current_type
          result << frame
          current_type = frame_type
        end
      end

      result
    end

    # TODO: Refactor.
    def generate_invasion_segments
      frames = start_and_end_frames
      segments = []
      start_frame = nil

      # If the first frame is an end frame, create a segment from the very first frame
      if frames.first && frames.first.text.match?(/Returning to your world/i)
        very_first_frame = all_frames.first
        segments << InvasionSegment.new(
          very_first_frame.timestamp,
          very_first_frame.video_file,
          frames.first.timestamp,
          frames.first.video_file
        )
      end

      frames.each do |frame|
        if frame.text.match?(/Defeat.*Host of Fingers!/i)
          start_frame = frame
        elsif frame.text.match?(/Returning to your world/i) && start_frame
          segments << InvasionSegment.new(
            start_frame.timestamp,
            start_frame.video_file,
            frame.timestamp,
            frame.video_file
          )
          start_frame = nil
        end
      end

      # If there's a start_frame without an end (invasion cut off at the end of recording)
      if start_frame
        very_last_frame = all_frames.last
        segments << InvasionSegment.new(
          start_frame.timestamp,
          start_frame.video_file,
          very_last_frame.timestamp,
          very_last_frame.video_file
        )
      end

      segments
    end

    def search_string(regex)
      @videos.flat_map do |video_file|
        video_file.frame_data.select do |frame|
          frame.text.match?(regex)
        end
      end
    end

  end
end
