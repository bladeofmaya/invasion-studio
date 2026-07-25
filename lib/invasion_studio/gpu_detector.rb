module InvasionStudio
  class GPUDetector
    def self.vaapi_available?
      return @vaapi_available if defined?(@vaapi_available)

      @vaapi_available = begin
        result = ProcessRunner.new.capture('vainfo') if File.exist?('/dev/dri/renderD128')
        result&.success? && result.stdout.include?('VAProfileH264')
      rescue StandardError
        false
      end
    end

    def self.ffmpeg_hwaccel_args
      return [] unless vaapi_available?

      [
        '-hwaccel', 'vaapi',
        '-vaapi_device', '/dev/dri/renderD128',
        '-hwaccel_output_format', 'vaapi'
      ]
    end
  end
end
