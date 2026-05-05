require 'optparse'

module InvasionExtractor
  module Commands
    class Benchmark < Base
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
          opts.banner = "Usage: bin/invasion_extractor benchmark [OPTIONS] VIDEO_FILES..."

          opts.on("--profile [TYPE]", "Profile type") { |v| @options[:profile] = v || 'all' }
          opts.on("--benchmark-output FILE", "Save benchmark report") { |v| @options[:benchmark_output] = v }
          opts.on("--ocr-provider NAME", "OCR provider to benchmark") { |v| @options[:ocr_provider] = v }
          opts.on("-h", "--help", "Show this help") { puts opts; exit 0 }
        end
      end

      def validate!
        if @argv.empty?
          puts "Error: No video files specified for benchmarking."
          puts "Usage: bin/invasion_extractor benchmark [OPTIONS] VIDEO_FILES..."
          exit 1
        end

        video_files = @argv.select { |f| File.exist?(f) }
        if video_files.empty?
          puts "Error: No valid video files found."
          exit 1
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
        video_files = @argv.select { |f| File.exist?(f) }

        puts "Running benchmark with #{video_files.length} video(s)..."
        puts "OCR Provider: #{@options[:ocr_provider]}"
        puts "Profile: #{@options[:profile]}"
        puts ""

        InvasionExtractor::BenchmarkRunner.measure(@options) do |benchmark|
          engine = InvasionExtractor::Engine.new(video_files, @options)
          engine.benchmark = benchmark
          engine.run!
        end
      end
    end
  end
end
