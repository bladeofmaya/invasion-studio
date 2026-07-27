# frozen_string_literal: true

require 'securerandom'

module InvasionStudio
  class ClipTrash
    def initialize(folder_path, storage, clock: -> { Time.now }, random_suffix: -> { SecureRandom.hex(4) })
      @folder_path = File.expand_path(folder_path)
      @storage = storage
      @clock = clock
      @random_suffix = random_suffix
    end

    def delete(clip)
      source_path = @storage.resolve(clip['path'])
      if source_path && File.exist?(source_path)
        trash_dir = File.join(@folder_path, '.trashed')
        FileUtils.mkdir_p(trash_dir)
        trash_path = unique_destination(trash_dir, clip['filename'])
        FileUtils.mv(source_path, trash_path)
        clip['trash_path'] = @storage.relative_path(trash_path)
      end

      clip['deleted'] = true
      true
    end

    def restore(clip)
      source_path = @storage.resolve(clip['path'])
      return false if source_path && File.exist?(source_path)

      trash_path = @storage.resolve(clip['trash_path']) ||
                   @storage.resolve(File.join('.trashed', clip['filename']))
      FileUtils.mv(trash_path, source_path) if trash_path && File.exist?(trash_path) && source_path
      clip['deleted'] = false
      clip.delete('trash_path')
      true
    end

    private

    def unique_destination(directory, filename)
      safe_filename = File.basename(filename.to_s)
      candidate = File.join(directory, safe_filename)
      return candidate unless File.exist?(candidate)

      extension = File.extname(safe_filename)
      basename = File.basename(safe_filename, extension)
      File.join(directory, "#{basename}_#{@clock.call.to_i}_#{@random_suffix.call}#{extension}")
    end
  end
end
