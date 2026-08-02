# frozen_string_literal: true

module InvasionStudio
  module ClipSequence
    PATTERN = /\A.+_(\d{5})\.[^.]+\z/

    module_function

    def highest_number(directory, repository: nil)
      registered = repository&.highest_clip_number.to_i
      on_disk = if File.directory?(directory)
                  Dir.each_child(directory).filter_map do |entry|
                    entry.match(PATTERN)&.[](1)&.to_i
                  end.max.to_i
                else
                  0
                end
      [registered, on_disk].max
    end

    def filename(number, extension, prefix: 'clip')
      format("#{prefix}_%05d#{extension}", number)
    end
  end
end
