# frozen_string_literal: true

module InvasionStudio
  class ClipImporter
    SUPPORTED_EXTENSIONS = %w[.mp4 .mkv .mov .avi .webm .flv .m4v .mpeg .mpg].freeze

    def initialize(project, storage: nil, repository: nil,
                   metadata_probe: ->(path) { Video.new(path).metadata },
                   thumbnail_job: InvasionStudio::Workers::ThumbnailJob)
      @project = project
      @storage = storage || project.storage
      @repository = repository || project.clip_repository
      @metadata_probe = metadata_probe
      @thumbnail_job = thumbnail_job
    end

    def import_upload(tempfile:, filename:)
      ext = File.extname(filename).downcase
      raise InvasionStudio::Error, "Unsupported file type: #{ext}" unless SUPPORTED_EXTENSIONS.include?(ext)

      key = unique_key(filename)
      stored_key = @storage.store(tempfile.path, key)
      raise InvasionStudio::Error, "Failed to store uploaded file" unless stored_key

      path = @storage.resolve(stored_key)
      metadata = probe_metadata(path)
      clip_id = stored_key.sub(/\.[^.]*\z/, '')

      clip = @repository.create(
        'id' => clip_id,
        'filename' => filename,
        'path' => stored_key,
        'source_kind' => 'uploaded',
        'duration' => metadata[:duration],
        'width' => metadata[:width],
        'height' => metadata[:height],
        'fps' => metadata[:fps],
        'video_codec' => metadata[:video_codec],
        'audio_codec' => metadata[:audio_codec],
        'filesize' => File.size(path)
      )

      enqueue_thumbnail(clip['id'])
      clip
    end

    private

    def enqueue_thumbnail(clip_id)
      @thumbnail_job.perform_async(clip_id, @project.folder_path)
    end

    def unique_key(filename)
      ext = File.extname(filename)
      base = File.basename(filename, ext)
      base = base.gsub(/[^a-zA-Z0-9_-]/, '_')
      candidate = "clips/#{base}#{ext}"
      return candidate unless @storage.exist?(candidate)

      counter = 1
      loop do
        candidate = "clips/#{base}_#{counter}#{ext}"
        return candidate unless @storage.exist?(candidate)

        counter += 1
      end
    end

    def probe_metadata(path)
      @metadata_probe.call(path)
    rescue StandardError
      {}
    end
  end
end
