# frozen_string_literal: true

module InvasionStudio
  module Webui
    # Only accepts extraction settings; output always belongs to the open project.
    class ExtractionRequest
      NUMBERS = {
        'ffmpeg_threads' => [4, 1..64, :integer],
        'ocr_workers' => [[Etc.nprocessors, 4].min, 1..64, :integer],
        'fps' => [1, 1..10, :integer],
        'pad_start' => [10, 0..3600, :float],
        'pad_end' => [7.5, 0..3600, :float]
      }.freeze
      FLAGS = %w[hwaccel no_cache].freeze
      attr_reader :paths, :options

      def initialize(paths, options)
        raise Error, 'Select at least one recording' unless paths.is_a?(Array) && !paths.empty?
        @paths = paths.map do |path|
          raise Error, 'Each recording must be a file path' unless path.is_a?(String) && !path.strip.empty?
          expanded = File.expand_path(path)
          unless MediaFiles.video?(expanded) && File.file?(expanded) && File.readable?(expanded)
            raise Error, "Recording is not a readable video file: #{path}"
          end
          expanded
        end.uniq
        @options = self.class.validate_options(options)
      end

      def self.validate_options(options)
        raise Error, 'Invalid extraction settings' unless options.is_a?(Hash)
        unknown = options.keys - NUMBERS.keys - FLAGS
        raise Error, "Unknown extraction settings: #{unknown.join(', ')}" unless unknown.empty?

        result = NUMBERS.to_h do |name, (default, range, type)|
          raw = options.fetch(name, default)
          value = Float(raw, exception: false) if raw.is_a?(Numeric) || raw.is_a?(String)
          unless value && value.finite? && range.cover?(value) && (type != :integer || value == value.to_i)
            raise Error, "#{name} must be #{type == :integer ? 'an integer' : 'a number'} between #{range.begin} and #{range.end}"
          end
          [name.to_sym, type == :integer ? value.to_i : value]
        end
        FLAGS.each do |name|
          value = options.fetch(name, false)
          raise Error, "#{name} must be true or false" unless value == true || value == false
          result[name.to_sym] = value
        end
        result
      end
    end
  end
end
