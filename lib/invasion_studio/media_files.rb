# frozen_string_literal: true

module InvasionStudio
  module MediaFiles
    VIDEO_EXTENSIONS = %w[.mp4 .mkv .avi .mov .webm .flv .wmv .m4v .mpeg .mpg].freeze

    module_function

    def video?(path)
      VIDEO_EXTENSIONS.include?(File.extname(path).downcase)
    end

    def discover(folder)
      Dir.glob(File.join(folder, '*')).select { |path| video?(path) }.sort
    end
  end
end
