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
    end
  end
end
