# frozen_string_literal: true

module InvasionStudio
  module Extraction
    class ClipExtractionStage
      # Clips written by the last run, as { path:, source: } hashes; source is
      # the recording the encounter starts in.
      attr_reader :created

      def initialize(options, reporter: Reporter.new(options),
                     clip_factory: ->(segment, clip_options) { Clip.new(segment, clip_options) })
        @options = options
        @reporter = reporter
        @clip_factory = clip_factory
        @created = []
      end

      def run(segments)
        @created = []
        return [] if segments.empty?

        outdir = @options[:outdir] || 'invasion_clips'
        prefix = @options[:prefix] || 'invasion'
        FileUtils.mkdir_p(outdir)
        # The folder scan is a safety floor for files the database does not
        # know (crashed runs, hand-copied files); :min_clip_number carries
        # the database's allocation in project mode.
        start_index = [highest_clip_number(outdir), @options[:min_clip_number].to_i].max
        @reporter.extracting
        @reporter.extraction_start(prefix, start_index)
        errors = extract(segments, outdir, prefix, start_index)
        @reporter.extraction_complete(segments.length)
        errors
      end

      private

      def extract(segments, outdir, prefix, start_index)
        errors = []
        segments.each_with_index do |segment, index|
          output = File.join(outdir, format("#{prefix}_%05d.mp4", start_index + index + 1))
          clip = @clip_factory.call(segment, @options)
          if clip.file_exists?(output)
            @reporter.clip_skipped(output)
          else
            clip.write(output)
            @created << { path: output, source: segment.start_video }
            @reporter.clip_extracted(output)
          end
        rescue StandardError => error
          raise unless @options[:continue_on_error]

          errors << [output, error]
          @reporter.clip_error(output, error)
        end
        errors
      end

      # Numbering continues from the highest numbered clip regardless of its
      # prefix, so mixed-prefix folders never produce a colliding or
      # out-of-sequence filename.
      def highest_clip_number(outdir)
        pattern = /\A.+_(\d{5})\.mp4\z/
        Dir.each_child(outdir).filter_map { |entry| entry.match(pattern)&.[](1)&.to_i }.max || 0
      end
    end
  end
end
