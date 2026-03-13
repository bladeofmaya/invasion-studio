module InvasionExtractor
  class Engine
    attr_reader :videos, :options, :progress_callback

    # This is the main entry point for straight up processing of videos.
    def self.run!(videos, options = {})
      new(videos, options)
    end

    def initialize(videos, options = {})
      @videos = videos.map do |video_file|
        InvasionExtractor::Video.new(video_file)
      end
      @options = options
      @progress_callback = options[:progress_callback]
    end

    def clips
      @clips ||= generate_clips
    end

    def extract_invasion_clips!(prefix = 'invasion', output_dir = 'invasion_clips', &block)
      @progress_callback = block if block_given?
      FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

      clips.each_with_index do |clip, index|
        report_progress(:generating_clip, index + 1, clips.length)
        output_file = File.join(output_dir, format("#{prefix}_%05d.mp4", index + 1))
        clip.write(output_file) unless clip.file_exists?(output_file)
      end
      report_progress(:generating_clip, clips.length, clips.length)
    end

    private

    def report_progress(event, current, total)
      return unless @progress_callback

      @progress_callback.call(event, current, total)
    end

    def generate_clips
      InvasionExtractor::Scanner.new(@videos).invasion_segments.map do |segment|
        InvasionExtractor::Clip.new(segment)
      end
    end
  end
end
