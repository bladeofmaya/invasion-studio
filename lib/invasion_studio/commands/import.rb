require 'optparse'

module InvasionStudio
  module Commands
    class Import < Base
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
          opts.banner = "Usage: invasion-studio import --project FOLDER CLIP [CLIP ...]"
          opts.on('--project FOLDER', 'Project that receives the clips') { |value| @options[:project] = value }
          opts.on('-q', '--quiet', 'Suppress non-error output') { @options[:quiet] = true }
          opts.on('-h', '--help', 'Show this help') { puts opts; exit 0 }
        end
      end

      def validate!
        unless @options[:project]
          raise Error, 'No project specified. Use --project FOLDER.'
        end
        unless File.directory?(@options[:project])
          raise Error, "#{@options[:project]} is not a valid project directory."
        end
        raise Error, 'No clips specified.' if @argv.empty?

        @argv.each do |path|
          raise Error, "#{path} is not a file." unless File.file?(path)
        end
      end

      def execute
        database = InvasionStudio::Database.migrate_to_current!(@options[:project])
        project = InvasionStudio::Project.new(@options[:project], database: database)
        imported = InvasionStudio::ProjectClipImporter.new(project).import(@argv)
        report(imported)
      ensure
        database&.disconnect
      end

      def report(imported)
        return if @options[:quiet]

        imported.each { |clip| puts "Imported #{clip['source_video']} as #{clip['filename']}" }
        puts "Imported #{imported.length} clip(s)."
      end
    end
  end
end
