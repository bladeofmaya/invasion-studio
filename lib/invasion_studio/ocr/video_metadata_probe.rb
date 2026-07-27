# frozen_string_literal: true

module InvasionStudio
  module OCR
    class VideoMetadataProbe
      def initialize(process_runner: ProcessRunner.new, debug: false)
        @process_runner = process_runner
        @debug = debug
      end

      def call(video_path)
        result = @process_runner.capture(
          'ffprobe', '-v', 'quiet', '-print_format', 'json', '-show_streams', '-show_format', video_path
        )
        raise Error, "ffprobe failed for #{video_path}: #{result.stderr}" unless result.success?

        payload = JSON.parse(result.stdout)
        streams = payload.fetch('streams', [])
        container = payload.fetch('format', {})
        video_stream = streams.find { |stream| stream['codec_type'] == 'video' } || streams.first
        raise Error, "ffprobe returned no video stream for #{video_path}" unless video_stream

        audio_stream = streams.find { |stream| stream['codec_type'] == 'audio' }
        {
          height: video_stream['height'],
          width: video_stream['width'],
          fps: parse_frame_rate(video_stream['r_frame_rate']),
          # Some containers (e.g. MKV) carry the duration only at format level
          duration: (video_stream['duration'] || container['duration'])&.to_f || 0,
          video_codec: video_stream['codec_name'],
          audio_codec: audio_stream && audio_stream['codec_name'],
          audio_stream_count: streams.count { |stream| stream['codec_type'] == 'audio' }
        }
      rescue JSON::ParserError, StandardError => error
        warn "Error extracting video metadata: #{error.message}" if @debug
        nil
      end

      private

      def parse_frame_rate(value)
        numerator, denominator = value.to_s.split('/', 2).map(&:to_f)
        return numerator unless denominator
        return 0.0 unless denominator.positive?

        numerator / denominator
      end
    end
  end
end
