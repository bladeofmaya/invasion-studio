# frozen_string_literal: true

require 'securerandom'

module InvasionStudio
  class ClipCatalog
    def initialize(folder_path, clips, id_generator: nil)
      @folder_path = File.expand_path(folder_path)
      @clips = clips
      @id_generator = id_generator || ->(base) { "#{base}-#{SecureRandom.uuid}" }
    end

    def all
      @clips
    end

    def active
      @clips.reject { |clip| clip['deleted'] }
    end

    def deleted
      @clips.select { |clip| clip['deleted'] }
    end

    def find(clip_id)
      @clips.find { |clip| clip['id'] == clip_id }
    end

    def path_for(clip)
      resolve(clip['path'])
    end

    def resolve(path)
      return nil if path.nil? || path.empty?

      expanded = File.expand_path(path, @folder_path)
      project_root = File.realpath(@folder_path)
      candidate = canonical_candidate(expanded)
      return nil unless candidate.start_with?("#{project_root}#{File::SEPARATOR}")

      candidate
    rescue Errno::ENOENT, Errno::EACCES
      nil
    end

    def relative_path(path)
      return path if path.nil? || path.empty? || !File.absolute_path(path).eql?(path)

      path.delete_prefix("#{@folder_path}#{File::SEPARATOR}")
    end

    def sync!(groups:)
      discover_new_clips
      migrate_clips
      remove_missing_clips
      groups.prune(@clips.map { |clip| clip['id'] })
      self
    end

    private

    def discover_new_clips
      known_filenames = @clips.map { |clip| clip['filename'] }
      known_ids = @clips.map { |clip| clip['id'] }
      MediaFiles.discover(@folder_path).each do |path|
        filename = File.basename(path)
        next if known_filenames.include?(filename)

        base_id = File.basename(filename, '.*')
        clip_id = known_ids.include?(base_id) ? @id_generator.call(base_id) : base_id
        known_ids << clip_id
        @clips << default_clip(clip_id, filename, path)
      end
    end

    def default_clip(clip_id, filename, path)
      {
        'id' => clip_id,
        'filename' => filename,
        'path' => relative_path(path),
        'title' => nil,
        'note' => '',
        'rating' => 0,
        'result' => nil,
        'cuts' => [],
        'deleted' => false
      }
    end

    def migrate_clips
      @clips.each do |clip|
        clip['title'] = nil unless clip.key?('title')
        clip['note'] = '' unless clip.key?('note')
        clip['rating'] = 0 unless clip.key?('rating')
        clip['result'] = nil unless clip.key?('result')
        clip['cuts'] = [] unless clip.key?('cuts')
        clip['deleted'] = false unless clip.key?('deleted')
        clip['path'] = relative_path(clip['path'])
      end
    end

    def remove_missing_clips
      @clips.reject! do |clip|
        source = path_for(clip)
        trash = resolve(clip['trash_path']) || resolve(File.join('.trashed', clip['filename']))
        !file_exists?(source) && !file_exists?(trash)
      end
    end

    def canonical_candidate(expanded)
      return File.realpath(expanded) if File.exist?(expanded)

      parent = File.dirname(expanded)
      canonical_parent = File.exist?(parent) ? File.realpath(parent) : File.expand_path(parent)
      File.join(canonical_parent, File.basename(expanded))
    end

    def file_exists?(path)
      path && File.exist?(path)
    end
  end
end
