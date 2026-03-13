module InvasionExtractor
  class GPUDetector
    GPU_TYPES = {
      nvidia: {
        encoder: 'h264_nvenc',
        decoder: 'h264_cuvid',
        check_cmd: 'nvidia-smi > /dev/null 2>&1'
      },
      amd: {
        encoder: 'h264_vaapi',
        decoder: 'h264_vaapi',
        check_cmd: 'vainfo 2>/dev/null | grep -q VAProfileH264Main'
      },
      intel: {
        encoder: 'h264_vaapi',
        decoder: 'h264_vaapi',
        check_cmd: 'vainfo 2>/dev/null | grep -q "Intel" && vainfo 2>/dev/null | grep -q VAProfileH264Main'
      }
    }.freeze

    def self.detect
      GPU_TYPES.each do |type, config|
        return type if system(config[:check_cmd])
      end
      nil
    end

    def self.available?
      !detect.nil?
    end

    def self.gpu_info
      type = detect
      return nil unless type

      GPU_TYPES[type].merge(type: type)
    end

    def self.ffmpeg_hwaccel_options
      gpu = gpu_info
      return [] unless gpu

      case gpu[:type]
      when :nvidia
        ['-hwaccel', 'cuda', '-hwaccel_output_format', 'cuda']
      when :amd, :intel
        ['-hwaccel', 'vaapi', '-hwaccel_output_format', 'vaapi', '-hwaccel_device', '/dev/dri/renderD128']
      else
        []
      end
    end

    def self.ffmpeg_encoder_options
      gpu = gpu_info
      return [] unless gpu

      ['-c:v', gpu[:encoder]]
    end
  end
end
