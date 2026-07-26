module InvasionStudio
  module OCR
    class TesseractProvider < Provider
      def initialize(options = {})
        @psm = Integer(options[:psm] || 6)
        @process_runner = options[:process_runner] || ProcessRunner.new
      end

      def recognize(image_path)
        result = @process_runner.capture(*command(image_path))
        raise RecognitionError, result.stderr unless result.success?

        result.stdout.strip
      rescue StandardError => e
        raise RecognitionError, "Tesseract failed to recognize #{image_path}: #{e.message}"
      end

      def recognize_batch(image_paths)
        return [] if image_paths.empty?

        list = Tempfile.new(['invasion-studio-tesseract', '.txt'])
        list.write(image_paths.join("\n"))
        list.write("\n")
        list.close
        result = @process_runner.capture(*command(list.path))
        raise RecognitionError, result.stderr unless result.success?

        pages = result.stdout.split("\f", -1).map(&:strip)
        pages.pop if pages.length == image_paths.length + 1 && pages.last.empty?
        unless pages.length == image_paths.length
          raise RecognitionError,
                "Tesseract returned #{pages.length} result for #{image_paths.length} images"
        end

        pages
      rescue StandardError => e
        raise RecognitionError, "Tesseract batch recognition failed: #{e.message}"
      ensure
        list&.close!
      end

      private

      def command(input)
        [
          'tesseract', input, 'stdout', '--psm', @psm.to_s,
          '-c', 'tessedit_char_whitelist=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ '
        ]
      end
    end

    class RecognitionError < StandardError; end
  end
end
