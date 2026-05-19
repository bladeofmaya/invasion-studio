require 'optparse'

module InvasionExtractor
  module Commands
    class Extract < Base
      def run
        parse_options!
        validate!
        check_dependencies!
        execute
      end

      private

      def parse_options!
        build_parser.parse!(@argv)
      end

      def build_parser
        OptionParser.new do |opts|
          opts.banner = "Usage: bin/invasion_extractor #{@options[:command]} [OPTIONS] VIDEO_FILES..."

          opts.on("-p", "--prefix PREFIX", "Prefix for output files") { |v| @options[:prefix] = v }
          opts.on("-o", "--outdir DIRECTORY", "Output directory") { |v| @options[:outdir] = v }
          opts.on("--fps RATE", Integer, "Frame extraction rate") { |v| @options[:fps] = v }
          opts.on("--no-cache", "Skip OCR cache") { @options[:no_cache] = true }
          opts.on("--pad-start SECONDS", Float, "Seconds before invasion") { |v| @options[:pad_start] = v }
          opts.on("--pad-end SECONDS", Float, "Seconds after invasion") { |v| @options[:pad_end] = v }
          opts.on("-d", "--debug", "Enable debug output") { @options[:debug] = true }
          opts.on("-q", "--quiet", "Suppress non-error output") { @options[:quiet] = true }
          opts.on("--continue-on-error", "Continue on errors") { @options[:continue_on_error] = true }
          opts.on("-h", "--help", "Show this help") { puts opts; exit 0 }
        end
      end

      def validate!
        if @argv.empty?
          puts "Error: No video files specified."
          puts "Usage: bin/invasion_extractor #{@options[:command]} [OPTIONS] VIDEO_FILES..."
          exit 1
        end

        video_files = @argv.select { |f| File.exist?(f) }
        if video_files.empty?
          puts "Error: No valid video files found."
          exit 1
        end

        if video_files.length < @argv.length
          puts "Warning: #{@argv.length - video_files.length} file(s) not found, skipping."
        end
      end

      def check_dependencies!
        InvasionExtractor.ensure_ffmpeg_installed
        InvasionExtractor.ensure_tesseract_installed
      rescue => e
        puts "Error: #{e.message}"
        exit 1
      end

      def execute
        engine = InvasionExtractor::Engine.new(video_files, @options)
        engine.run!

        print_scan_results(engine) if @options[:command] == 'scan'
      end

      def video_files
        @argv.select { |f| File.exist?(f) }
      end

      def print_scan_results(engine)
        puts "\nDetected Invasions:"
        engine.scanner.invasion_segments.each_with_index do |segment, index|
          puts "  [#{index + 1}] #{segment.start_time} -> #{segment.end_time}"
          if segment.start_video != segment.end_video
            puts "      Cross-file: #{File.basename(segment.start_video)} -> #{File.basename(segment.end_video)}"
          else
            puts "      File: #{File.basename(segment.start_video)}"
          end
        end
        puts "\nTotal: #{engine.scanner.invasion_segments.length} invasion(s) detected"
      end
    end
  end
end
