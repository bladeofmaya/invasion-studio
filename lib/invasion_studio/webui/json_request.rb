# frozen_string_literal: true

module InvasionStudio
  module Webui
    class InvalidJsonRequest < Error; end

    class JsonRequest
      def parse(io)
        JSON.parse(io.read)
      rescue JSON::ParserError
        raise InvalidJsonRequest, 'Invalid JSON request body'
      end
    end
  end
end
