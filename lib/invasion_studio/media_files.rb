# frozen_string_literal: true

module InvasionStudio
  module MediaFiles
    VIDEO_EXTENSIONS = %w[.mp4 .mkv .avi .mov .webm .flv .wmv .m4v .mpeg .mpg].freeze

    module_function

    def video?(path)
      VIDEO_EXTENSIONS.include?(File.extname(path).downcase)
    end

    def discover(folder)
      root = Dir.glob(File.join(folder, '*')).select { |path| video?(path) }
      clips_dir = Dir.glob(File.join(folder, 'clips', '*')).select { |path| video?(path) }
      (root + clips_dir).sort
    end
  end
end
