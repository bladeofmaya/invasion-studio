require 'optparse'

module InvasionStudio
  module Commands
    class Normalize < Base
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
          opts.banner = "Usage: invasion-studio normalize [OPTIONS] FOLDER\n\n" \
                        "Renames a project's clips to clip_00001.mp4, clip_00002.mp4, ... in\n" \
                        "library order, updating the database, thumbnails, compilations, tags,\n" \
                        "and cut markers. Stop the WebUI for this project before running.\n\n"

          opts.on("--dry-run", "Show the rename plan without changing anything") { @options[:dry_run] = true }
          opts.on("-q", "--quiet", "Suppress non-error output") { @options[:quiet] = true }
          opts.on("-h", "--help", "Show this help") { puts opts; exit 0 }
        end
      end

      def validate!
        if @argv.empty?
          puts "Error: No folder specified."
          puts "Usage: invasion-studio normalize [OPTIONS] FOLDER"
          exit 1
        end

        @folder = @argv.first

        unless File.directory?(@folder)
          puts "Error: #{@folder} is not a valid directory."
          exit 1
        end
      end

      def execute
        database = InvasionStudio::Database.migrate_to_current!(@folder)
        storage = InvasionStudio::Storage::LocalDiskStorage.new(@folder)
        repository = InvasionStudio::Database::ClipRepository.new(database, storage)
        # Opening the project imports legacy metadata and registers loose
        # files, so the plan covers everything in the folder.
        InvasionStudio::Project.new(@folder, database: database, storage: storage, clip_repository: repository)

        normalizer = InvasionStudio::ClipNormalizer.new(
          database: database, storage: storage, repository: repository
        )
        changes = @options[:dry_run] ? normalizer.plan : normalizer.run
        report(changes, repository)
      ensure
        database&.disconnect
      end

      def report(changes, repository)
        return if @options[:quiet]

        changes.each do |change|
          puts "#{change[:filename]} -> #{change[:new_filename]}"
        end

        verb = @options[:dry_run] ? 'Would rename' : 'Renamed'
        puts "#{verb} #{changes.length} clip(s)."
        trashed = repository.deleted.length
        puts "Skipped #{trashed} trashed clip(s); they are renamed after restoring." if trashed.positive?
      end
    end
  end
end
