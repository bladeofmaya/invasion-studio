require 'json'
require 'fileutils'

module InvasionExtractor
  # Handles persistence of sessions to disk
  class SessionStore
    SESSIONS_DIR = File.join(Dir.home, '.invasion_extractor', 'sessions')

    def initialize
      ensure_directory_exists
    end

    def save(session)
      path = session_path(session.session_id)
      File.write(path, JSON.pretty_generate(session.to_h))
      session
    end

    def load(session_id)
      path = session_path(session_id)
      return nil unless File.exist?(path)

      data = JSON.parse(File.read(path))
      Session.from_h(data)
    rescue JSON::ParserError => e
      puts "Error loading session #{session_id}: #{e.message}"
      nil
    end

    def delete(session_id)
      path = session_path(session_id)
      File.delete(path) if File.exist?(path)
    end

    def list
      return [] unless Dir.exist?(SESSIONS_DIR)

      Dir.glob(File.join(SESSIONS_DIR, '*.json')).map do |path|
        session_id = File.basename(path, '.json')
        load(session_id)
      end.compact.sort_by(&:updated_at).reverse
    end

    def exists?(session_id)
      File.exist?(session_path(session_id))
    end

    def clear_all
      return unless Dir.exist?(SESSIONS_DIR)

      Dir.glob(File.join(SESSIONS_DIR, '*.json')).each do |path|
        File.delete(path)
      end
    end

    private

    def ensure_directory_exists
      FileUtils.mkdir_p(SESSIONS_DIR)
    end

    def session_path(session_id)
      File.join(SESSIONS_DIR, "#{session_id}.json")
    end
  end
end
