# frozen_string_literal: true

module InvasionStudio
  module OCR
    class CropGeometry
      BASE_HEIGHT = 1440.0
      BASE_CROP = { width: 700, height: 130, x: 950, y: 960 }.freeze

      def call(metadata)
        scale = (metadata[:height] || BASE_HEIGHT).to_f / BASE_HEIGHT
        BASE_CROP.transform_values { |value| even(value * scale) }
      end

      private

      def even(value)
        (value.to_i / 2) * 2
      end
    end
  end
end
