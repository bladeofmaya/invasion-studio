require 'optparse'

module InvasionExtractor
  class CLI
    VERSION = InvasionExtractor::VERSION

    DEFAULT_OPTIONS = {
      command: 'extract',
      prefix: 'invasion',
      outdir: 'invasion_clips',
      fps: 2,
      jobs: Etc.nprocessors,
      ocr_provider: 'tesseract',
      use_gpu: false,
      no_cache: false,
      no_progress: false,
      quiet: false,
      debug: false,
      continue_on_error: false,
      benchmark: false,
      pad_start: 10.0,
      pad_end: 7.5
    }.freeze

    VALID_COMMANDS = %w[extract scan status cache benchmark].freeze

    attr_reader :options

    def initialize(argv = ARGV)
      @argv = argv.dup
      @options = DEFAULT_OPTIONS.dup
    end

    def run
      parse_global_options!
      detect_command!
      execute_command!
    end

    private

    def parse_global_options!
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: bin/invasion_extractor [COMMAND] [OPTIONS] [VIDEO_FILES...]"

        opts.on("-h", "--help", "Show this help") { usage }
        opts.on("-v", "--version", "Show version") { version }
        opts.on("-d", "--debug", "Enable debug output") { @options[:debug] = true }
        opts.on("-q", "--quiet", "Suppress non-error output") { @options[:quiet] = true }
        opts.on("--show-cache", "Show cache information and exit") { show_cache; exit 0 }
        opts.on("--clear-cache", "Clear OCR cache before processing") { clear_cache }
      end

      parser.order!(@argv) rescue nil
    end

    def detect_command!
      potential_command = @argv.first unless @argv.empty? || @argv.first.start_with?('-')

      if potential_command && VALID_COMMANDS.include?(potential_command)
        @options[:command] = @argv.shift
      end
    end

    def execute_command!
      command_class = command_class_for(@options[:command])
      command = command_class.new(@options, @argv)
      command.run
    rescue Interrupt
      puts "\nOperation interrupted by user."
      exit 130
    rescue => e
      puts "\nError: #{e.message}"
      puts e.backtrace.first(5).join("\n") if @options[:debug]
      exit 1
    end

    def command_class_for(command_name)
      case command_name
      when 'extract', 'scan' then Commands::Extract
      when 'status' then Commands::Status
      when 'cache' then Commands::Cache
      when 'benchmark' then Commands::Benchmark
      else Commands::Extract
      end
    end

    def usage
      puts "Invasion Extractor v#{VERSION}"
      puts "Automatically detect and extract invasion clips from Elden Ring gameplay"
      puts ""
      puts "Usage: bin/invasion_extractor [COMMAND] [OPTIONS] [VIDEO_FILES...]"
      puts ""
      puts "Commands:"
      puts "  extract              Extract invasion clips from videos (default)"
      puts "  scan                 Scan videos and output invasion timestamps only"
      puts "  status               Show session status and resume information"
      puts "  cache                Manage OCR cache (list, clear, stats)"
      puts "  benchmark            Run performance benchmarks"
      puts ""
      puts "Options:"
      puts "  Output:"
      puts "    -p, --prefix PREFIX          Prefix for output files (default: invasion)"
      puts "    -o, --outdir DIRECTORY       Output directory (default: ./invasion_clips)"
      puts ""
      puts "  Processing:"
      puts "    -j, --jobs N                 Parallel jobs for extraction (default: auto)"
      puts "    --fps RATE                   Frame extraction rate (default: 2)"
      puts "    --ocr-provider NAME          OCR engine: tesseract (default), easyocr, ollama"
      puts "    --use-gpu                    Enable GPU acceleration for frame extraction"
    puts "    --no-cache                   Skip OCR cache, force re-processing"
    puts "    --show-cache                 Show cache information and exit"
    puts "    --clear-cache                Clear OCR cache before processing"
    puts ""
    puts "  Resume & Progress:"
      puts "    --resume SESSION             Resume from a saved session"
      puts "    --save-session NAME          Save session for resuming later"
      puts "    --no-progress                Disable progress bars"
      puts "    --quiet                      Suppress non-error output"
      puts ""
      puts "  Detection:"
      puts "    --pad-start SECONDS          Seconds to include before invasion (default: 10)"
      puts "    --pad-end SECONDS            Seconds to include after invasion (default: 7.5)"
      puts "    --start-pattern REGEX        Custom regex for invasion start"
      puts "    --end-pattern REGEX          Custom regex for invasion end"
      puts ""
      puts "  Benchmarking:"
      puts "    --benchmark                  Enable timing benchmarks"
      puts "    --profile [TYPE]             Profile: memory, cpu, all"
      puts "    --benchmark-output FILE      Save benchmark report to JSON"
      puts ""
      puts "  General:"
      puts "    -h, --help                   Show this help message"
      puts "    -v, --version                Show version"
      puts "    -d, --debug                  Enable debug output"
      puts "    -c, --config FILE            Load configuration from YAML file"
      puts ""
      puts "Examples:"
      puts "  # Basic extraction"
      puts "  bin/invasion_extractor ~/Videos/Capture/*.mp4"
      puts ""
      puts "  # With prefix and output directory"
      puts "  bin/invasion_extractor extract -p ps-daggers-tt-04 -o ~/Videos/ER/clips ~/Videos/Capture/*.mp4"
      puts ""
      puts "  # Resume a long session"
      puts "  bin/invasion_extractor extract --resume session-001 --save-session session-001 ~/Videos/Capture/*.mp4"
      puts ""
      puts "  # Scan only - find invasions without extracting"
      puts "  bin/invasion_extractor scan ~/Videos/Capture/*.mp4"
      puts ""
      puts "  # Run with full benchmarking"
      puts "  bin/invasion_extractor extract --benchmark --profile all --benchmark-output report.json ~/Videos/*.mp4"
      puts ""
      puts "  # GPU-accelerated extraction with EasyOCR"
      puts "  bin/invasion_extractor extract --ocr-provider easyocr --use-gpu ~/Videos/Capture/*.mp4"
      puts ""
      puts "Cache directory: ~/.invasion_extractor/cache/"
      puts "Sessions directory: ~/.invasion_extractor/sessions/"
      exit 0
    end

    def version
      puts "Invasion Extractor v#{VERSION}"
      exit 0
    end

    def show_cache
      cache_dir = File.join(Dir.home, '.invasion_extractor', 'cache')

      if Dir.exist?(cache_dir)
        files = Dir.glob(File.join(cache_dir, '*.yml'))
        total_size = files.sum { |f| File.size(f) }

        puts "Cache Statistics:"
        puts "  Location: #{cache_dir}"
        puts "  Entries: #{files.length}"
        puts "  Total Size: #{format_cache_size(total_size)}"

        if files.any?
          puts "  Entries:"
          files.each do |f|
            stat = File.stat(f)
            puts "    #{File.basename(f, '.yml')} (#{format_cache_size(stat.size)}, #{stat.mtime.strftime('%Y-%m-%d')})"
          end
        end
      else
        puts "Cache directory does not exist."
        puts "Location: #{cache_dir}"
      end
    end

    def clear_cache
      cache_dir = File.join(Dir.home, '.invasion_extractor', 'cache')

      if Dir.exist?(cache_dir)
        files = Dir.glob(File.join(cache_dir, '*'))
        files.each { |f| File.delete(f) }
        puts "Cache cleared (#{files.length} entries removed)."
      else
        puts "Cache directory does not exist. Nothing to clear."
      end
    end

    def format_cache_size(bytes)
      if bytes < 1024
        "#{bytes}B"
      elsif bytes < 1024 * 1024
        "#{(bytes / 1024.0).round(1)}KB"
      else
        "#{(bytes / 1024.0 / 1024.0).round(1)}MB"
      end
    end
  end
end
