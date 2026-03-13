module InvasionExtractor
  module OCR
    class EasyOCRProvider < Provider
      DEFAULT_LANGUAGE = 'en'
      DEFAULT_GPU = true

      def initialize(options = {})
        @language = options[:language] || DEFAULT_LANGUAGE
        @use_gpu = options.fetch(:gpu, DEFAULT_GPU)
        @python_path = options[:python_path] || detect_python
        @easyocr_script = create_easyocr_script
      end

      def recognize(image_path)
        raise RecognitionError, 'EasyOCR requires Python with easyocr installed' unless python_available?

        require 'open3'
        require 'json'
        require 'tempfile'

        output_file = Tempfile.new(['easyocr_output', '.json'])

        cmd = [
          @python_path,
          @easyocr_script,
          image_path,
          @language,
          @use_gpu.to_s,
          output_file.path
        ]

        _, stderr, status = Open3.capture3(*cmd)

        raise RecognitionError, "EasyOCR failed: #{stderr}" unless status.success?

        result = JSON.parse(File.read(output_file.path))
        output_file.close
        output_file.unlink

        result['text'] || ''
      rescue JSON::ParserError => e
        raise RecognitionError, "Failed to parse EasyOCR output: #{e.message}"
      end

      def name
        'easyocr'
      end

      def gpu_accelerated?
        @use_gpu
      end

      private

      def detect_python
        %w[python3 python].each do |cmd|
          return cmd if system("#{cmd} --version > /dev/null 2>&1")
        end
        'python3'
      end

      def python_available?
        system("#{@python_path} --version > /dev/null 2>&1")
      end

      def create_easyocr_script
        script = Tempfile.new(['easyocr_runner', '.py'])
        script.write(<<~PYTHON)
          import sys
          import json

          try:
              import easyocr
          except ImportError:
              print(json.dumps({"error": "easyocr not installed"}), file=sys.stderr)
              sys.exit(1)

          if len(sys.argv) < 5:
              print(json.dumps({"error": "Usage: script.py image_path language use_gpu output_file"}), file=sys.stderr)
              sys.exit(1)

          image_path = sys.argv[1]
          language = sys.argv[2]
          use_gpu = sys.argv[3].lower() == 'true'
          output_file = sys.argv[4]

          try:
              reader = easyocr.Reader([language], gpu=use_gpu)
              result = reader.readtext(image_path, detail=0)
              text = ' '.join(result)
          #{'    '}
              with open(output_file, 'w') as f:
                  json.dump({"text": text.strip()}, f)
          except Exception as e:
              print(json.dumps({"error": str(e)}), file=sys.stderr)
              sys.exit(1)
        PYTHON
        script.close
        script.path
      end
    end
  end
end
