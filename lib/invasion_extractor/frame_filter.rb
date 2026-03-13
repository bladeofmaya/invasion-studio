require 'vips'

module InvasionExtractor
  class FrameFilter
    DEFAULT_BRIGHTNESS_THRESHOLD = 15
    DEFAULT_EDGE_DENSITY_THRESHOLD = 0.05

    attr_reader :brightness_threshold, :edge_density_threshold, :enabled

    def initialize(options = {})
      @enabled = options.fetch(:enabled, true)
      @brightness_threshold = options[:brightness_threshold] || DEFAULT_BRIGHTNESS_THRESHOLD
      @edge_density_threshold = options[:edge_density_threshold] || DEFAULT_EDGE_DENSITY_THRESHOLD
      @stats = { total: 0, skipped_dark: 0, skipped_edges: 0, passed: 0 }
    end

    def should_process?(frame_path)
      @stats[:total] += 1

      unless File.exist?(frame_path)
        @stats[:passed] += 1
        return true
      end

      unless @enabled
        @stats[:passed] += 1
        return true
      end

      begin
        image = Vips::Image.new_from_file(frame_path)

        brightness = calculate_brightness(image)
        if brightness < @brightness_threshold
          @stats[:skipped_dark] += 1
          return false
        end

        edge_density = calculate_edge_density(image)
        if edge_density < @edge_density_threshold
          @stats[:skipped_edges] += 1
          return false
        end

        @stats[:passed] += 1
        true
      rescue Vips::Error
        @stats[:passed] += 1
        true
      end
    end

    def stats
      @stats.dup
    end

    def reset_stats!
      @stats = { total: 0, skipped_dark: 0, skipped_edges: 0, passed: 0 }
    end

    private

    def calculate_brightness(image)
      return 0 if image.width == 0 || image.height == 0

      gray = image.bands == 1 ? image : image.colourspace('b-w')
      gray.avg
    end

    def calculate_edge_density(image)
      return 0 if image.width == 0 || image.height == 0

      gray = image.bands == 1 ? image : image.colourspace('b-w')

      sobel = gray.sobel

      total_pixels = image.width * image.height
      strong_edges = sobel.more(20).avg * total_pixels / 255.0

      strong_edges / total_pixels
    end
  end
end
