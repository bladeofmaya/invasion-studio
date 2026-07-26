# frozen_string_literal: true

module InvasionStudio
  module Extraction
    class ScanStage
      def initialize(reporter:)
        @reporter = reporter
      end

      def run(scanner)
        @reporter.scanning
        scanner.invasion_segments.tap { |segments| @reporter.scan_complete(scanner, segments) }
      end
    end
  end
end
