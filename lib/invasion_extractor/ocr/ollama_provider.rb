module InvasionExtractor
  module OCR
    class OllamaProvider < Provider
      DEFAULT_MODEL = 'llava:7b'
      DEFAULT_HOST = 'http://localhost:11434'
      DEFAULT_PROMPT = 'Extract ONLY the visible text from this image. Return just the text, nothing else. Be concise.'

      def initialize(options = {})
        @model = options[:model] || DEFAULT_MODEL
        @host = options[:host] || DEFAULT_HOST
        @prompt = options[:prompt] || DEFAULT_PROMPT
        @batch_size = options[:batch_size] || 1
      end

      def recognize(image_path)
        require 'faraday'
        require 'base64'

        client = Faraday.new(@host) do |f|
          f.request :json
          f.response :json
          f.options.timeout = 30 # LLM can be slow
        end

        image_data = Base64.strict_encode64(File.read(image_path))

        response = client.post('/api/generate', {
                                 model: @model,
                                 prompt: @prompt,
                                 images: [image_data],
                                 stream: false
                               })

        raise RecognitionError, "Ollama API error: #{response.status} - #{response.body}" unless response.success?

        result = response.body
        result['response']&.strip || ''
      rescue LoadError => e
        raise LoadError, "Missing dependency for OllamaProvider: #{e.message}. Add to Gemfile: gem 'faraday'"
      rescue Faraday::Error => e
        raise RecognitionError, "Failed to connect to Ollama: #{e.message}"
      end

      def recognize_batch(image_paths)
        return [] if image_paths.empty?
        return image_paths.map { |path| recognize(path) } if @batch_size == 1

        image_paths.each_slice(@batch_size).flat_map do |batch|
          batch.map { |path| recognize(path) }
        end
      end

      def gpu_available?
        require 'faraday'

        client = Faraday.new(@host) do |f|
          f.request :json
          f.response :json
          f.options.timeout = 5
        end

        response = client.get('/api/ps')
        return false unless response.success?

        models = response.body['models'] || []
        models.any? { |m| m['name']&.include?(@model) }
      rescue StandardError
        false
      end

      def name
        'ollama'
      end
    end
  end
end
