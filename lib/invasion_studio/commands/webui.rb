require 'optparse'

module InvasionStudio
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
          opts.banner = "Usage: invasion-studio webui [OPTIONS] FOLDER"

          opts.on("-p", "--port PORT", Integer, "Server port (default: 4567)") { |v| @options[:port] = v }
          opts.on("--parent-pid PID", Integer, "Exit when the parent process exits") { |v| @options[:parent_pid] = v }
          opts.on("-h", "--help", "Show this help") { puts opts; exit 0 }
        end
      end

      def validate!
        if @argv.empty?
          puts "Error: No folder specified."
          puts "Usage: invasion-studio webui [OPTIONS] FOLDER"
          exit 1
        end

        @folder = @argv.first

        unless File.directory?(@folder)
          puts "Error: #{@folder} is not a valid directory."
          exit 1
        end

        port = @options[:port] || 4567
        raise Error, 'port must be between 0 and 65535' unless (0..65_535).cover?(port)

        parent_pid = @options[:parent_pid]
        raise Error, 'parent PID must be greater than 1' if parent_pid && parent_pid <= 1
      end

      def execute
        port = @options[:port] || 4567
        require_relative '../webui/server'
        InvasionStudio::Webui::Server.run!(
          @folder,
          port: port,
          quiet: @options[:quiet],
          parent_pid: @options[:parent_pid]
        )
      end
    end
  end
end
