# frozen_string_literal: true

require 'digest'

module InvasionStudio
  # Content identity is independent of filenames and survives application restarts.
  class RecordingImportHistory
    def initialize(database)
      @records = database[:recording_imports]
    end

    def fingerprints(paths)
      seen = {}
      paths.to_h do |path|
        yield(path) if block_given?
        before = File.stat(path)
        digest = Digest::SHA256.file(path).hexdigest
        after = File.stat(path)
        unless before.size == after.size && before.mtime == after.mtime && before.ino == after.ino
          raise Error, "Recording changed while checking it: #{path}"
        end
        raise Error, "The same recording was selected twice: #{path}" if seen[digest]
        seen[digest] = true
        [digest, path]
      end
    end

    def reserve(fingerprints, allow_reimport: false)
      inserted = []
      @records.db.transaction(mode: :immediate) do
        duplicates = @records.where(digest: fingerprints.keys).select_map(:digest)
        if duplicates.any? && !allow_reimport
          paths = duplicates.map { |digest| fingerprints.fetch(digest) }
          raise Error, "Already imported or previously attempted in this project: #{paths.join(', ')}. No recordings were processed. Use Import again only if you intend to create another set of clips."
        end
        (fingerprints.keys - duplicates).each do |digest|
          @records.insert(digest: digest, source_path: fingerprints.fetch(digest), created_at: Time.now.utc.iso8601)
          inserted << digest
        end
      end
      inserted
    end

    def release(digests)
      @records.where(digest: digests).delete unless digests.empty?
    end
  end
end
