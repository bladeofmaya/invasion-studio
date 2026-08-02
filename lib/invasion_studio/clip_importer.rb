# frozen_string_literal: true

module InvasionStudio
  class ClipImporter
    SUPPORTED_EXTENSIONS = %w[.mp4 .mkv .mov .avi .webm .flv .m4v .mpeg .mpg].freeze
    MAX_UPLOAD_BYTES = 4 * 1024 * 1024 * 1024

    def initialize(project, storage: nil, repository: nil,
                   metadata_probe: ->(path) { Video.new(path).metadata },
                   thumbnail_job: InvasionStudio::Workers::ThumbnailJob,
                   max_upload_bytes: MAX_UPLOAD_BYTES)
      @project = project
      @storage = storage || project.storage
      @repository = repository || project.clip_repository
      @metadata_probe = metadata_probe
      @thumbnail_job = thumbnail_job
      @max_upload_bytes = max_upload_bytes
    end

    def import_upload(tempfile:, filename:)
      ext = File.extname(filename).downcase
      raise InvasionStudio::Error, "Unsupported file type: #{ext}" unless SUPPORTED_EXTENSIONS.include?(ext)

      filesize = File.size(tempfile.path)
      raise InvasionStudio::Error, "File is empty" if filesize.zero?
      if filesize > @max_upload_bytes
        raise InvasionStudio::Error, "File is too large (maximum is #{human_size(@max_upload_bytes)})"
      end

      # Probe before storing so garbage never enters the library.
      metadata = probe_metadata(tempfile.path)
      raise InvasionStudio::Error, "Not a readable video file" if metadata.nil?

      key = unique_key(filename)
      stored_key = @storage.store(tempfile.path, key)
      raise InvasionStudio::Error, "Failed to store uploaded file" unless stored_key

      clip_id = stored_key.sub(/\.[^.]*\z/, '')

      clip = @repository.upsert_by_path(
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
        'filesize' => filesize
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

    # nil means the file is not a video ffprobe can read; callers reject it.
    def probe_metadata(path)
      @metadata_probe.call(path)
    rescue StandardError
      nil
    end

    def human_size(bytes)
      if bytes >= 1024**3
        gb = bytes.to_f / 1024**3
        format(gb == gb.round ? '%d GB' : '%.1f GB', gb)
      else
        "#{(bytes.to_f / 1024**2).ceil} MB"
      end
    end
  end
end
