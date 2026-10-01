# frozen_string_literal: true

module InvasionStudio
  module Webui
    class ExtractionProgress < Extraction::Reporter
      def initialize(&update)
        super(quiet: true)
        @update = update
        @extracted = 0
        @detected = 0
      end

      def processing(video)
        @update.call(stage: 'ocr', file: File.basename(video.path), current: nil, total: nil)
      end

      def ocr_frame_options(_video)
        {
          extract_progress_callback: ->(current, total) { @update.call(frames_extracted: current) },
          progress_callback: ->(current, total) { @update.call(current: current, total: total) }
        }
      end

      def scanning
        @update.call(stage: 'scanning', file: nil, current: nil, total: nil)
      end

      def scan_complete(_scanner, segments)
        @detected = segments.length
        @update.call(detected: @detected)
      end

      def extracting
        @update.call(stage: 'extracting', current: 0, total: @detected)
      end

      def clip_extracted(path)
        @extracted += 1
        @update.call(file: File.basename(path), current: @extracted, total: @detected)
      end
    end
  end
end
