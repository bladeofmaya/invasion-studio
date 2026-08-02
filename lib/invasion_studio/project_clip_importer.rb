# frozen_string_literal: true

module InvasionStudio
  class ProjectClipImporter
    def initialize(project)
      @project = project
    end

    def import(paths)
      sources = validate(paths)
      clips_directory = File.join(@project.folder_path, 'clips')
      number = ClipSequence.highest_number(
        clips_directory, repository: @project.clip_repository
      )
      stored = []
      sources.each do |source|
        number += 1
        extension = File.extname(source).downcase
        key = File.join('clips', ClipSequence.filename(number, extension))
        raise Error, "Failed to import #{source}" unless @project.storage.store(source, key)

        stored << { key: key, source: source }
      end

      register(stored)
    rescue StandardError
      stored&.each { |entry| @project.storage.delete(entry[:key]) }
      @project.sync_clips! if stored&.any?
      raise
    end

    private

    def validate(paths)
      raise Error, 'No clips specified.' if paths.empty?

      paths.map do |path|
        source = File.expand_path(path)
        raise Error, "#{path} is not a file." unless File.file?(source)
        unless MediaFiles.video?(source)
          raise Error, "Unsupported file type: #{File.extname(source).downcase}"
        end

        source
      end
    end

    def register(stored)
      @project.sync_clips!
      stored.map do |entry|
        id = File.basename(entry[:key], File.extname(entry[:key]))
        @project.clip_repository.update(
          id,
          'source_kind' => 'imported',
          'source_video' => File.basename(entry[:source])
        )
        @project.clip_repository.find(id)
      end
    end
  end
end
