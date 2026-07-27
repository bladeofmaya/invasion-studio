# frozen_string_literal: true

module InvasionStudio
  # Probes a clip's media file and stores the technical metadata
  # (duration, dimensions, fps, codecs, filesize) on its database record.
  class ClipMetadataUpdater
    def initialize(project, storage: nil, repository: nil,
                   metadata_probe: ->(path) { Video.new(path).metadata })
      @storage = storage || project.storage
      @repository = repository || project.clip_repository
      @metadata_probe = metadata_probe
    end

    def update(clip_id)
      clip = @repository.find(clip_id)
      return false unless clip

      path = @repository.path_for(clip)
      return false unless path && File.exist?(path)

      metadata = probe(path)
      return false unless metadata

      @repository.update(
        clip_id,
        'duration' => metadata[:duration],
        'width' => metadata[:width],
        'height' => metadata[:height],
        'fps' => metadata[:fps],
        'video_codec' => metadata[:video_codec],
        'audio_codec' => metadata[:audio_codec],
        'filesize' => File.size(path)
      )
      @repository.find(clip_id)
    end

    private

    def probe(path)
      @metadata_probe.call(path)
    rescue StandardError
      nil
    end
  end
end
