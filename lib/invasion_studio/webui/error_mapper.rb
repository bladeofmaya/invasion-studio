# frozen_string_literal: true

module InvasionStudio
  module Webui
    class NotFoundError < Error; end
    class ValidationError < Error; end
    class ConflictError < Error; end
    class ProcessingError < Error; end

    class ErrorMapper
      STATUS_BY_ERROR = {
        InvalidJsonRequest => 400,
        ValidationError => 400,
        NotFoundError => 404,
        ConflictError => 409,
        ProcessingError => 422
      }.freeze

      def map(error)
        status = STATUS_BY_ERROR.find { |type, _status| error.is_a?(type) }&.last || 500
        [status, { error: error.message }]
      end
    end
  end
end
