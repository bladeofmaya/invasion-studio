module InvasionExtractor
  class Engine
    attr_accessor :videos, :clips

    # This is the main entry point for straight up processing of videos.
    def self.run!(videos, options = {})
      new(videos, options)
    end

    def initialize(videos, options = {})
      @videos = videos.map do |video_file|
        InvasionExtractor::Video.process(video_file)
      end

      # @clips = generate_clips
    end

    # def write_clips(prefix, output_dir)
    #   @clips.each_with_index do |clip, index|
    #     output_file = File.join(output_dir, format("#{prefix}_%03d.mp4", index + 1))
    #     clip.write(output_file) unless clip.file_exists?(output_file)
    #   end
    # end

    # private

    # def generate_clips
    #   InvasionExtractor::InvasionScanner.new(@videos).invasion_segments.map do |segment|
    #     InvasionExtractor::Clip.new(segment)
    #   end
    # end

  end
end
