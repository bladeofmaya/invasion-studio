# frozen_string_literal: true

module InvasionStudio
  module Webui
    class PreviewRemuxer
      def initialize(folder_path, process_runner: ProcessRunner.new)
        # Must stay in sync with Server.run! (wipe on startup) and
        # StorageStatistics (cache size / Clear Cache in settings).
        @preview_dir = File.join(folder_path, '.preview_cache')
        @process_runner = process_runner
      end

      def remux(original_path, track_number)
        FileUtils.mkdir_p(@preview_dir)
        preview_path = preview_path_for(original_path, track_number)
        return preview_path if valid_output?(preview_path)

        audio_index = track_number - 1
        success = @process_runner.run(
          Executables.ffmpeg, '-y', '-i', original_path,
          '-map', '0:v:0', '-map', "0:a:#{audio_index}",
          '-c', 'copy', preview_path
        )
        return preview_path if success && valid_output?(preview_path)

        File.delete(preview_path) if File.exist?(preview_path)
        nil
      end

      private

      def preview_path_for(original_path, track_number)
        mtime = File.mtime(original_path).to_i
        basename = File.basename(original_path, '.*')
        File.join(@preview_dir, "#{basename}_audio#{track_number}_#{mtime}.mp4")
      end

      def valid_output?(path)
        File.exist?(path) && File.size(path).positive?
      end
    end
  end
end
