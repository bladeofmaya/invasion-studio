require 'optparse'

module InvasionExtractor
  module Commands
    class Status < Base
      def run
        parse_options!
        execute
      end

      private

      def parse_options!
        build_parser.parse!(@argv)
      end

      def build_parser
        OptionParser.new do |opts|
          opts.banner = "Usage: bin/invasion_extractor status [OPTIONS]"

          opts.on("--save-session NAME", "Show specific session") { |v| @options[:save_session] = v }
          opts.on("-h", "--help", "Show this help") { puts opts; exit 0 }
        end
      end

      def execute
        store = InvasionExtractor::SessionStore.new

        if @options[:save_session]
          show_session(store, @options[:save_session])
        else
          list_sessions(store)
        end
      end

      def show_session(store, session_id)
        session = store.load(session_id)
        if session
          reporter = InvasionExtractor::ProgressReporter.new(quiet: false)
          reporter.session_summary(session)
        else
          puts "Session '#{session_id}' not found."
          exit 1
        end
      end

      def list_sessions(store)
        sessions = store.list

        if sessions.empty?
          puts "No sessions found."
          puts "Sessions are stored in: #{InvasionExtractor::SessionStore::SESSIONS_DIR}"
        else
          puts "Sessions:"
          puts "-" * 80
          sessions.each do |session|
            status_icon = case session.status
                          when 'completed' then '✓'
                          when 'interrupted' then '⚠'
                          when 'error' then '✗'
                          else '○'
                          end

            puts "#{status_icon} #{session.session_id}"
            puts "    Status: #{session.status}"
            puts "    Created: #{session.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
            puts "    Videos: #{session.videos.length} (#{session.completed_videos.length}/#{session.videos.length} completed)"
            puts "    Invasions: #{session.detected_invasions.length} | Clips: #{session.completed_clips.length}/#{session.clips_to_extract.length}"
            puts ""
          end
          puts "-" * 80
          puts "Use --save-session NAME to view detailed status for a specific session"
        end
      end
    end
  end
end
