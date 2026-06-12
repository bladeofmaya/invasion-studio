require 'optparse'

module InvasionExtractor
  module Commands
    class Webui < Base
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
          opts.banner = "Usage: bin/invasion_extractor webui [OPTIONS] FOLDER"

          opts.on("-p", "--port PORT", Integer, "Server port (default: 4567)") { |v| @options[:port] = v }
          opts.on("-h", "--help", "Show this help") { puts opts; exit 0 }
        end
      end

      def validate!
        if @argv.empty?
          puts "Error: No folder specified."
          puts "Usage: bin/invasion_extractor webui [OPTIONS] FOLDER"
          exit 1
        end

        @folder = @argv.first

        unless File.directory?(@folder)
          puts "Error: #{@folder} is not a valid directory."
          exit 1
        end
      end

      def execute
        port = @options[:port] || 4567
        require_relative '../webui/server'
        InvasionExtractor::Webui::Server.run!(@folder, port: port, quiet: @options[:quiet])
      end
    end
  end
end
