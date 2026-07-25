module InvasionStudio
  module OCR
    class TesseractProvider < Provider
      def initialize(options = {})
        @psm = Integer(options[:psm] || 6)
        @process_runner = options[:process_runner] || ProcessRunner.new
      end

      def recognize(image_path)
        result = @process_runner.capture(
          'tesseract', image_path, 'stdout', '--psm', @psm.to_s,
          '-c', 'tessedit_char_whitelist=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ '
        )
        raise RecognitionError, result.stderr unless result.success?

        result.stdout.strip
      rescue StandardError => e
        raise RecognitionError, "Tesseract failed to recognize #{image_path}: #{e.message}"
      end
    end

    class RecognitionError < StandardError; end
  end
end
