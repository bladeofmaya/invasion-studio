# frozen_string_literal: true

module InvasionStudio
  module Webui
    # Storage overview for the settings dialog: how much disk the project's
    # clips, thumbnails, exports, trash, caches, and database occupy.
    class StorageStatistics
      def initialize(project, cache_dirs: nil)
        @project = project
        @folder = project.folder_path
        @cache_dirs = cache_dirs || [
          File.join(@folder, '.preview_cache'),
          InvasionStudio::Paths.cache_dir
        ]
      end

      def call
        clips = clip_stats
        stats = {
          'clips' => clips,
          'thumbnails' => dir_stats(File.join(@folder, 'thumbnails')),
          'exports' => dir_stats(File.join(@folder, 'exports')),
          'trash' => dir_stats(File.join(@folder, '.trashed')),
          'cache' => cache_stats,
          'database' => { 'bytes' => database_bytes }
        }
        stats['total_bytes'] = stats.sum { |_key, value| value['bytes'] }
        stats
      end

      # Removes the contents of the cache directories (preview remux cache
      # and the global OCR cache). Returns the number of bytes freed.
      def clear_cache!
        freed = cache_stats['bytes']
        @cache_dirs.each do |dir|
          next unless File.directory?(dir)

          Dir.children(dir).each { |child| FileUtils.rm_rf(File.join(dir, child)) }
        end
        freed
      end

      private

      def clip_stats
        repository = @project.clip_repository
        clips = @project.clips
        bytes = clips.sum do |clip|
          path = repository.path_for(clip)
          path && File.file?(path) ? File.size(path) : 0
        end
        {
          'count' => clips.length,
          'bytes' => bytes,
          'duration_seconds' => clips.sum { |clip| clip['duration'].to_f }
        }
      end

      def cache_stats
        @cache_dirs.map { |dir| dir_stats(dir) }
                   .reduce({ 'count' => 0, 'bytes' => 0 }) do |total, stats|
          { 'count' => total['count'] + stats['count'], 'bytes' => total['bytes'] + stats['bytes'] }
        end
      end

      def database_bytes
        Dir.glob(File.join(@folder, 'project.db*')).select { |file| File.file?(file) }
           .sum { |file| File.size(file) }
      end

      def dir_stats(dir)
        return { 'count' => 0, 'bytes' => 0 } unless File.directory?(dir)

        files = Dir.glob(File.join(dir, '**', '*'), File::FNM_DOTMATCH)
                   .select { |file| File.file?(file) }
        { 'count' => files.length, 'bytes' => files.sum { |file| File.size(file) } }
      end
    end
  end
end
