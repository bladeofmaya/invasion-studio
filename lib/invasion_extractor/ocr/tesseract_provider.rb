module InvasionExtractor
  module OCR
    class TesseractProvider < Provider
      def initialize(options = {})
        @psm = options[:psm] || 6
      end

      def recognize(image_path)
        # ponytail: direct CLI avoids rtesseract object overhead and lets us pass whitelist
        `tesseract #{image_path} stdout --psm #{@psm} -c "tessedit_char_whitelist=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ " 2>/dev/null`.strip
      rescue StandardError => e
        raise RecognitionError, "Tesseract failed to recognize #{image_path}: #{e.message}"
      end
    end

    class RecognitionError < StandardError; end
  end
end
