# frozen_string_literal: true

module InvasionStudio
  module Executables
    TOOLS = {
      ffmpeg: 'INVASION_STUDIO_FFMPEG',
      ffprobe: 'INVASION_STUDIO_FFPROBE',
      tesseract: 'INVASION_STUDIO_TESSERACT'
    }.freeze

    module_function

    TOOLS.each do |name, environment_variable|
      define_method(name) do |environment = ENV|
        configured_path = environment[environment_variable]
        configured_path.nil? || configured_path.empty? ? name.to_s : configured_path
      end
    end
  end
end
