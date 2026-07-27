# frozen_string_literal: true

module InvasionStudio
  # Registers clips produced by an extraction run in a project database with
  # extraction provenance. Opening the project discovers the new files; this
  # stamps them as extracted and records which recording they came from.
  class ExtractionImporter
    def initialize(folder_path, project: nil)
      @project = project || Project.new(folder_path)
    end

    # created: [{ path:, source: }] as reported by ClipExtractionStage.
    # Returns the number of clips recorded.
    def record(created)
      return 0 if created.empty?

      repository = @project.clip_repository
      clips_by_path = repository.all.to_h { |clip| [clip['path'], clip] }

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
