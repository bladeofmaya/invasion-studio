# frozen_string_literal: true

module InvasionStudio
  module Extraction
    class OcrStage
      Result = Data.define(:videos, :errors)

      def initialize(options, reporter: Reporter.new(options))
        @options = options
        @reporter = reporter
      end

      def run(videos)
        successful = []
        errors = []
        videos.each do |video|
          @reporter.processing(video)
          frames = video.frames(@reporter.ocr_frame_options(video))
          @reporter.frames_processed(frames)
          @reporter.debug_frames(video.path, frames)
          successful << video
        rescue StandardError => error
          raise unless @options[:continue_on_error]

          errors << [video.path, error]
          @reporter.video_error(video.path, error)
        end
        Result.new(successful, errors)
      end
    end
  end
end
