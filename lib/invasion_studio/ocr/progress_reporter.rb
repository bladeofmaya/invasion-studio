# frozen_string_literal: true

module InvasionStudio
  module OCR
    class ProgressReporter
      attr_reader :current

      def initialize(total:, callback: nil)
        @total = total
        @callback = callback
        @current = 0
        @mutex = Mutex.new
      end

      def advance
        @mutex.synchronize do
          @current += 1
          @callback&.call(@current, @total)
        end
      end
    end
  end
end
