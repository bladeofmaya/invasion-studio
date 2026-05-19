module InvasionExtractor
  class GPUDetector
    def self.vaapi_available?
      return @vaapi_available if defined?(@vaapi_available)

      @vaapi_available = begin
        File.exist?('/dev/dri/renderD128') &&
          system('vainfo 2>/dev/null | grep -q VAProfileH264')
      rescue
        false
      end
    end

    def self.ffmpeg_hwaccel_args
      return [] unless vaapi_available?

      [
        '-hwaccel', 'vaapi',
        '-hwaccel_output_format', 'vaapi',
        '-hwaccel_device', '/dev/dri/renderD128'
      ]
    end
  end
end
