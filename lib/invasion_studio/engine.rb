module InvasionStudio
  class Engine
    attr_reader :videos, :options, :errors

    def self.run!(videos, options = {})
      new(videos, options).tap(&:run!)
    end

    def initialize(videos, options = {})
      @options = options
      @errors = []
      @video_factory = options[:video_factory] || ->(path, video_options) { Video.new(path, video_options) }
      @scanner_factory = options[:scanner_factory] || ->(items) { Scanner.new(items) }
      @clip_factory = options[:clip_factory] || ->(segment, clip_options) { Clip.new(segment, clip_options) }
      @videos = videos.map { |path| @video_factory.call(path, @options) }

      reporter = options[:reporter] || Extraction::Reporter.new(@options)
      @ocr_stage = options[:ocr_stage] || Extraction::OcrStage.new(@options, reporter: reporter)
      @scan_stage = options[:scan_stage] || Extraction::ScanStage.new(reporter: reporter)
      @clip_extraction_stage = options[:clip_extraction_stage] || Extraction::ClipExtractionStage.new(
        @options,
        reporter: reporter,
        clip_factory: @clip_factory
      )
    end

    def run!
      return self if @videos.empty?

      ocr_result = @ocr_stage.run(@videos)
      @videos = ocr_result.videos
      @errors.concat(ocr_result.errors)
      invalidate_scan_results

      segments = @scan_stage.run(scanner)
      @errors.concat(@clip_extraction_stage.run(segments)) unless @options[:command] == 'scan'
      self
    end

    def clips
      @clips ||= scanner.invasion_segments.map do |segment|
        @clip_factory.call(segment, @options)
      end.freeze
    end

    def scanner
      @scanner ||= @scanner_factory.call(@videos)
    end

    private

    def invalidate_scan_results
      @scanner = nil
      @clips = nil
    end
  end
end
