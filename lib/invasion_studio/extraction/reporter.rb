# frozen_string_literal: true

module InvasionStudio
  module Extraction
    class Reporter
      def initialize(options)
        @options = options
      end

      def processing(video)
        puts "Processing: #{File.basename(video.path)}" unless quiet?
      end

      def ocr_frame_options(video)
        return {} if quiet?

        total = estimated_frames(video)
        return {} unless total.positive?

        extraction = progress_bar('  Extracting frames [:bar] :current/:total (:percent)', total)
        ocr = progress_bar('  OCR               [:bar] :current/:total (:percent) :elapsed ETA::eta', total)
        {
          extract_progress_callback: ->(current, _total) { extraction.current = current },
          progress_callback: ->(current, _total) { ocr.current = current }
        }
      end

      def frames_processed(frames)
        puts "  #{frames.length} frames processed" unless quiet?
      end

      def debug_frames(video_path, frames)
        return unless @options[:debug]

        debug_file = "#{VideoHasher.hash(video_path)}.debug.yml"
        data = frames.map { |frame| { timestamp: frame.timestamp, text: frame.text } }
        File.write(debug_file, data.to_yaml)
        puts "  Debug written to: #{debug_file}" unless quiet?
      end

      def video_error(path, error)
        warn "Skipping #{path}: #{error.message}" unless quiet?
      end

      def scanning
        puts 'Scanning for invasions...' unless quiet?
      end

      def scan_complete(scanner, segments)
        if @options[:debug]
          puts "  Matched #{scanner.matched_frames.length} frames:"
          scanner.matched_frames.each do |frame|
            type = EncounterMatcher.new.classify(frame.text).to_s.upcase
            puts "    [#{type}] #{frame.timestamp} => #{frame.text.inspect}"
          end
        end
        puts "  #{segments.length} invasions detected" unless quiet?
      end

      def extracting
        puts 'Extracting clips...' unless quiet?
      end

      def extraction_start(prefix, index)
        return if quiet? || index.zero?

        puts "  Starting from #{prefix}_#{format('%05d', index + 1)}"
      end

      def clip_skipped(path)
        puts "  Skipping #{File.basename(path)} (already exists)" unless quiet?
      end

      def clip_extracted(path)
        puts "  Extracted #{File.basename(path)}" unless quiet?
      end

      def clip_error(path, error)
        warn "Skipping #{path}: #{error.message}" unless quiet?
      end

      def extraction_complete(count)
        puts "  #{count} clips extracted" unless quiet?
      end

      private

      def quiet? = @options[:quiet]

      def estimated_frames(video)
        metadata = video.metadata
        fps = @options[:fps] || 1
        metadata && metadata[:duration].positive? ? (metadata[:duration] * fps).to_i : 0
      end

      def progress_bar(template, total)
        TTY::ProgressBar.new(template, total: total, width: 30)
      end
    end
  end
end
