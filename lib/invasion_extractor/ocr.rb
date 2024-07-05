module InvasionExtractor
  class Ocr
    class << self
      def run(frames, video)
        executable = File.expand_path('../../bin/darwin/vision_kit_adapter.swift', __dir__)
        # TODO: Implement OS Seleciton logic here

        all_frame_data = []

        # TODO: Memory / performance optimization
        # Bigger number, more memory which can lead to errors (text not being read)
        total_batches = (frames.size / 500.0).ceil

        frames.each_slice(500).with_index do |batch, index|
          puts "Processing batch #{index + 1} of #{total_batches}"
          output = `#{executable} #{batch.join(' ')}`
          if $?.success?
            all_frame_data.concat(parse_json(output, video))
          else
            raise Error, "OCR process failed for batch #{index + 1}: #{output}"
          end
        end
        all_frame_data
      end

      private

      def parse_json(output, video)
        JSON.parse(output).map do |frame_data|
          InvasionExtractor::Frame.new(
            extract_frame_number(frame_data['path']),
            frame_data['text'].join("\n"),
            frame_number_to_timestamp(extract_frame_number(frame_data['path'])),
            video
          )
        end
      rescue JSON::ParserError => e
        raise Error, "Failed to parse JSON output: #{e.message}"
      end

      def extract_frame_number(path)
        File.basename(path).scan(/\d+/).first.to_i
      end

      def frame_number_to_timestamp(frame_number)
        seconds = (frame_number - 1) / 2.0  # Assuming 2 fps
        minutes, seconds = seconds.divmod(60)
        hours, minutes = minutes.divmod(60)
        format("%02d:%02d:%06.3f", hours, minutes, seconds)
      end
    end
  end
end
