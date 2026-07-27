# frozen_string_literal: true

module InvasionStudio
  # Registers clips produced by an extraction run in a project database with
  # extraction provenance, and answers which clip numbers the project has
  # already handed out. The database is the source of truth for numbering:
  # trashed clips keep their number even though their file has left clips/.
  class ExtractionImporter
    def initialize(folder_path, project: nil)
      @project = project || Project.new(folder_path)
    end

    # Highest clip sequence number registered in the project, regardless of
    # whether the file is currently in clips/ (trashed) or is not an mp4.
    def highest_clip_number
      @project.clip_repository.highest_clip_number
    end

    # created: [{ path:, source: }] as reported by ClipExtractionStage.
    # Returns the number of clips recorded.
    def record(created)
      return 0 if created.empty?

      # The project was opened (and scanned) before extraction wrote the new
      # files — re-scan so they are registered.
      @project.sync_clips!

      repository = @project.clip_repository
      clips_by_path = repository.all.reject { |clip| clip['deleted'] }
                                .to_h { |clip| [clip['path'], clip] }

      created.count do |entry|
        relative = repository.relative_path(File.expand_path(entry[:path]))
        clip = clips_by_path[relative]
        next false unless clip

        repository.update(
          clip['id'],
          'source_kind' => 'extracted',
          'source_video' => File.basename(entry[:source].to_s)
        )
      end
    end
  end
end
