# frozen_string_literal: true

module InvasionStudio
  module OCR
    class FrameDiscovery
      POLL_INTERVAL = 0.1

      def initialize(sleeper: ->(interval) { sleep interval })
        @sleeper = sleeper
      end

      def each(directory, producer:, total: 0, progress: nil)
        frame_number = 1

        loop do
          path = File.join(directory, format('frame_%06d.jpg', frame_number))
          if File.file?(path)
            yield path
            progress&.call(frame_number, total)
            frame_number += 1
          elsif producer.alive?
            @sleeper.call(POLL_INTERVAL)
          else
            break
          end
        end
      end
    end
  end
end
