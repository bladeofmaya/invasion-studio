require 'rtesseract'

module InvasionExtractor
  module OCR
    class TesseractProvider < Provider
      def initialize(options = {})
        @options = { psm: 6 }.merge(options)
      end

      def recognize(image_path)
        RTesseract.new(image_path, @options).to_s.strip
      rescue StandardError => e
        raise RecognitionError, "Tesseract failed to recognize #{image_path}: #{e.message}"
      end
    end

    class RecognitionError < StandardError; end
  end
end
