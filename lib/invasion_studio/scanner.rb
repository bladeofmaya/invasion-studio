module InvasionStudio
  class Scanner
    Segment = Data.define(:start_time, :start_video, :end_time, :end_video)

    START_REGEX = EncounterMatcher::START_REGEX
    END_REGEX = EncounterMatcher::END_REGEX

    attr_reader :invasion_segments, :matched_frames

    def initialize(videos, matcher: EncounterMatcher.new)
      @videos = videos
      @matcher = matcher
      @matched_frames = collect_matched_frames.freeze
      @invasion_segments = generate_invasion_segments
    end

    private

    def collect_matched_frames
      frames = []
      @videos.each do |video|
        video_frames = video.frames
        @last_frame = video_frames.last unless video_frames.empty?
        video_frames.each do |frame|
          frames << frame if @matcher.classify(frame.text)
        end
      end
      frames
    end

    def generate_invasion_segments
      relevant_frames = @matched_frames
      return [] if relevant_frames.empty?

      segments = []
      start_frame = nil

      if @matcher.classify(relevant_frames.first.text) == :end
        start_frame = OpenStruct.new(timestamp: "00:00:00", video_path: relevant_frames.first.video_path)
      end

      relevant_frames.each do |frame|
        case @matcher.classify(frame.text)
        when :start
          start_frame = frame
        when :end
          next unless start_frame

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
      @last_frame
    end
  end
end
