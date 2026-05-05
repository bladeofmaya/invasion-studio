require 'optparse'

module InvasionExtractor
  module Commands
    class Cache < Base
      def run
        parse_options!
        execute
      end

      private

      def parse_options!
        build_parser.parse!(@argv)
        @options[:cache_command] = @argv.shift || 'stats'
      end

      def build_parser
        OptionParser.new do |opts|
          opts.banner = "Usage: bin/invasion_extractor cache [COMMAND]"
          opts.separator ""
          opts.separator "Commands:"
          opts.separator "  list     List cached entries"
          opts.separator "  clear    Clear all cached data"
          opts.separator "  stats    Show cache statistics"
          opts.on("-h", "--help", "Show this help") { puts opts; exit 0 }
        end
      end

      def execute
        cache_dir = File.join(Dir.home, '.invasion_extractor', 'cache')

        case @options[:cache_command]
        when 'list' then list_cache(cache_dir)
        when 'clear' then clear_cache(cache_dir)
        when 'stats' then cache_stats(cache_dir)
        end
      end

      def list_cache(cache_dir)
        if Dir.exist?(cache_dir)
          files = Dir.glob(File.join(cache_dir, '*.yml'))
          if files.empty?
            puts "No cached entries found."
          else
            puts "Cached OCR entries:"
            files.each do |f|
              stat = File.stat(f)
              size = stat.size
              size_str = format_size(size)
              puts "  #{File.basename(f, '.yml')} (#{size_str}, #{stat.mtime.strftime('%Y-%m-%d')})"
            end
          end
        else
          puts "Cache directory does not exist."
        end
      end

      def clear_cache(cache_dir)
        if Dir.exist?(cache_dir)
          files = Dir.glob(File.join(cache_dir, '*'))
          files.each { |f| File.delete(f) }
          puts "Cache cleared (#{files.length} entries removed)."
        else
          puts "Cache directory does not exist."
        end
      end

      def cache_stats(cache_dir)
        if Dir.exist?(cache_dir)
          files = Dir.glob(File.join(cache_dir, '*.yml'))
          total_size = files.sum { |f| File.size(f) }
          puts "Cache Statistics:"
          puts "  Location: #{cache_dir}"
          puts "  Entries: #{files.length}"
          puts "  Total Size: #{format_size(total_size)}"
        else
          puts "Cache directory does not exist."
          puts "Location: #{cache_dir}"
        end
      end

      def format_size(bytes)
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
end
