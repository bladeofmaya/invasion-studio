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
          opts.on("-j", "--jobs N", Integer, "Parallel jobs") { |v| @options[:jobs] = v }
          opts.on("--fps RATE", Integer, "Frame extraction rate") { |v| @options[:fps] = v }
          opts.on("--ocr-provider NAME", "OCR provider (tesseract, easyocr, ollama)") { |v| @options[:ocr_provider] = v }
          opts.on("--use-gpu", "Enable GPU acceleration") { @options[:use_gpu] = true }
          opts.on("--no-cache", "Skip OCR cache") { @options[:no_cache] = true }
          opts.on("--filter", "Enable frame pre-filtering (saves time but may miss frames)") { @options[:filter_enabled] = true }
          opts.on("--save-frames", "Preserve extracted frame images for debugging") { @options[:save_frames] = true }
          opts.on("--resume SESSION", "Resume from session") { |v| @options[:resume] = v }
          opts.on("--save-session NAME", "Save session ID") { |v| @options[:save_session] = v }
          opts.on("--no-progress", "Disable progress bars") { @options[:no_progress] = true }
          opts.on("-d", "--debug", "Enable debug output") { @options[:debug] = true }
          opts.on("-q", "--quiet", "Suppress non-error output") { @options[:quiet] = true }
          opts.on("--pad-start SECONDS", Float, "Seconds before invasion") { |v| @options[:pad_start] = v }
          opts.on("--pad-end SECONDS", Float, "Seconds after invasion") { |v| @options[:pad_end] = v }
          opts.on("--start-pattern REGEX", "Custom start pattern") { |v| @options[:start_pattern] = v }
          opts.on("--end-pattern REGEX", "Custom end pattern") { |v| @options[:end_pattern] = v }
          opts.on("--benchmark", "Enable benchmarks") { @options[:benchmark] = true }
          opts.on("--profile [TYPE]", "Profile (memory, cpu, all)") { |v| @options[:profile] = v || 'all' }
          opts.on("--benchmark-output FILE", "Save benchmark report") { |v| @options[:benchmark_output] = v }
          opts.on("-c", "--config FILE", "Config file") { |v| @options[:config] = v }
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
        engine.session.detected_invasions.each do |invasion|
          puts "  [#{invasion[:index] + 1}] #{invasion[:start_time]} → #{invasion[:end_time]}"
          if invasion[:start_video] != invasion[:end_video]
            puts "      Cross-file: #{File.basename(invasion[:start_video])} → #{File.basename(invasion[:end_video])}"
          else
            puts "      File: #{File.basename(invasion[:start_video])}"
          end
        end
        puts "\nTotal: #{engine.session.detected_invasions.length} invasion(s) detected"
      end
    end
  end
end
