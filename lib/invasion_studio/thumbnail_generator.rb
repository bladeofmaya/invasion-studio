# frozen_string_literal: true

require 'fileutils'

module InvasionStudio
  class ThumbnailGenerator
    DEFAULT_WIDTH = 480

    def initialize(project, storage: nil, repository: nil, process_runner: ProcessRunner.new)
      @project = project
      @storage = storage || project.storage
      @repository = repository || project.clip_repository
      @process_runner = process_runner
    end

    def generate(clip_id)
      clip = @repository.find(clip_id)
      return false unless clip

      source_path = @storage.resolve(clip['path'])
      return false unless source_path && File.exist?(source_path)

      thumbnail_key = thumbnail_key_for(clip_id)
      thumbnail_path = @storage.resolve(thumbnail_key)
      if thumbnail_path && File.exist?(thumbnail_path)
        # The file can exist while the record was never updated (e.g. an
        # earlier job lost a database race after writing the file) — repair
        # the record instead of leaving the clip permanently thumbnail-less.
        @repository.update(clip_id, 'thumbnail_path' => thumbnail_key) unless clip['thumbnail_path'] == thumbnail_key
        return @repository.find(clip_id)
      end

      timestamp = extract_timestamp(source_path)
      FileUtils.mkdir_p(File.dirname(thumbnail_path))

      success = @process_runner.run(
        'ffmpeg', '-y', '-ss', format_time(timestamp),
        '-i', source_path,
        '-vframes', '1',
        '-q:v', '2',
        '-vf', "scale=#{DEFAULT_WIDTH}:-1",
        thumbnail_path
      )

      if success && File.exist?(thumbnail_path)
        @repository.update(clip_id, 'thumbnail_path' => thumbnail_key)
        @repository.find(clip_id)
      else
        false
      end
    end

    private

    def extract_timestamp(source_path)
      video = Video.new(source_path)
      metadata = video.metadata
      duration = metadata[:duration].to_f
      [duration * 0.25, 1.0].max
    rescue StandardError
      1.0
    end

    def format_time(seconds)
      Time.at(seconds).utc.strftime('%H:%M:%S.%L')
    end

    def thumbnail_key_for(clip_id)
      safe_id = clip_id.to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
      "thumbnails/#{safe_id}.jpg"
    end
  end
end
