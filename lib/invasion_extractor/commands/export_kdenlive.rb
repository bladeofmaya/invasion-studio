require 'optparse'

module InvasionExtractor
  module Commands
    class ExportKdenlive < Base
      def run
        parse_options!
        validate!
        execute
      end

      private

      def parse_options!
        build_parser.parse!(@argv)
      end

      def build_parser
        OptionParser.new do |opts|
          opts.banner = "Usage: bin/invasion_extractor export-kdenlive [OPTIONS] FOLDER"

          opts.on("-o", "--output FILE", "Output .kdenlive file path") { |v| @options[:output] = v }
          opts.on("-t", "--transition SECONDS", Float, "Transition duration in seconds (default: 2.5)") { |v| @options[:transition_duration] = v }
          opts.on("-h", "--help", "Show this help") { puts opts; exit 0 }
        end
      end

      def validate!
        if @argv.empty?
          puts "Error: No folder specified."
          puts "Usage: bin/invasion_extractor export-kdenlive [OPTIONS] FOLDER"
          exit 1
        end

        @folder = @argv.first

        unless File.directory?(@folder)
          puts "Error: #{@folder} is not a valid directory."
          exit 1
        end
      end

      def execute
        exporter = InvasionExtractor::KdenliveExporter.new(@folder, @options)
        output_path = @options[:output] || File.join(@folder, 'timeline.kdenlive')
        exporter.run!(output_path)
        puts "Spliced video: #{File.join(@folder, 'combined.mp4')}" unless @options[:quiet]
        puts "Kdenlive project: #{output_path}" unless @options[:quiet]
      end
    end
  end
end
