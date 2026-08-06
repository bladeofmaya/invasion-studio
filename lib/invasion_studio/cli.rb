require 'optparse'

module InvasionStudio
  class CLI
    VERSION = InvasionStudio::VERSION

    DEFAULT_OPTIONS = {
      command: 'extract',
      prefix: 'invasion',
      outdir: 'invasion_clips',
      fps: 1,
      no_cache: false,
      quiet: false,
      debug: false,
      continue_on_error: false,
      pad_start: 10.0,
      pad_end: 7.5,
      ffmpeg_threads: 4
    }.freeze

    VALID_COMMANDS = %w[extract scan export-kdenlive concat webui normalize import].freeze
    COMMANDS = {
      'extract' => Commands::Extract,
      'scan' => Commands::Extract,
      'export-kdenlive' => Commands::ExportKdenlive,
      'concat' => Commands::Concat,
      'webui' => Commands::Webui,
      'normalize' => Commands::Normalize,
      'import' => Commands::Import
    }.freeze

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
        opts.banner = "Usage: invasion-studio [COMMAND] [OPTIONS] [VIDEO_FILES...]"

        opts.on("-h", "--help", "Show this help") { usage }
        opts.on("-v", "--version", "Show version") { version }
        opts.on("-d", "--debug", "Enable debug output") { @options[:debug] = true }
        opts.on("-q", "--quiet", "Suppress non-error output") { @options[:quiet] = true }
        opts.on("--hwaccel", "Enable VAAPI hardware acceleration for frame decoding") { @options[:hwaccel] = true }
        opts.on("--ffmpeg-threads N", Integer, "ffmpeg encoding threads (default: 4)") { |v| @options[:ffmpeg_threads] = v }
      end

      parser.order!(@argv)
    rescue OptionParser::ParseError => e
      raise Error, e.message
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
      COMMANDS.fetch(command_name, Commands::Extract)
    end

    def usage
      puts "Invasion Studio v#{VERSION}"
      puts "Automatically detect and extract invasion clips from Elden Ring gameplay"
      puts ""
      puts "Usage: invasion-studio [COMMAND] [OPTIONS] [VIDEO_FILES...]"
      puts ""
      puts "Commands:"
      puts "  extract              Extract invasion clips from videos (default)"
      puts "  scan                 Scan videos and output invasion timestamps only"
      puts "  export-kdenlive      Splice clips and create a Kdenlive project"
      puts "  concat               Concatenate clips into a single video (no re-encoding)"
      puts "  webui                Launch a web UI to manage clips and export"
      puts "  normalize            Rename a project's clips to clip_00001.mp4, clip_00002.mp4, ..."
      puts "  import               Copy clips into a project with sequential names"
      puts ""
      puts "Options:"
      puts "  Output:"
      puts "    -p, --prefix PREFIX          Prefix for output files (default: invasion)"
      puts "    -o, --outdir DIRECTORY       Output directory (default: ./invasion_clips)"
      puts "    --project DIRECTORY          Extract into a project's clips/ folder and register the clips"
      puts ""
  puts "  Processing:"
  puts "    --fps RATE                   Frame extraction rate (default: 1)"
  puts "    --ffmpeg-threads N           ffmpeg encoding threads (default: 4)"
  puts "    --no-cache                   Skip OCR cache, force re-processing"
  puts "    --hwaccel                    Enable VAAPI hardware acceleration"
  puts ""
      puts "  Detection:"
      puts "    --pad-start SECONDS          Seconds to include before invasion (default: 10)"
      puts "    --pad-end SECONDS            Seconds to include after invasion (default: 7.5)"
      puts ""
      puts "  General:"
      puts "    -d, --debug                  Enable debug output (writes frame text to YAML)"
      puts "    -q, --quiet                  Suppress non-error output"
      puts "    -h, --help                   Show this help message"
      puts "    -v, --version                Show version"
      puts ""
      puts "Examples:"
      puts "  # Basic extraction"
      puts "  invasion-studio ~/Videos/Capture/*.mp4"
      puts ""
      puts "  # With prefix and output directory"
      puts "  invasion-studio extract -p ps-daggers-tt-04 -o ~/Videos/ER/clips ~/Videos/Capture/*.mp4"
      puts ""
      puts "  # Scan only - find invasions without extracting"
      puts "  invasion-studio scan ~/Videos/Capture/*.mp4"
      puts ""
      puts "  # Debug - see what OCR detected at each timestamp"
      puts "  invasion-studio extract -d ~/Videos/Capture/*.mp4"
      exit 0
    end

    def version
      puts "Invasion Studio v#{VERSION}"
      exit 0
    end
  end
end
