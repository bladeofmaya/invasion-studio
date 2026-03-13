require 'vips'

module InvasionExtractor
  class FrameFilter
    DEFAULT_BRIGHTNESS_THRESHOLD = 15
    DEFAULT_EDGE_DENSITY_THRESHOLD = 0.05
    DEFAULT_TEXT_LIKE_THRESHOLD = 0.02

    attr_reader :brightness_threshold, :edge_density_threshold, :text_like_threshold, :enabled

    def initialize(options = {})
      @enabled = options.fetch(:enabled, true)
      @brightness_threshold = options[:brightness_threshold] || DEFAULT_BRIGHTNESS_THRESHOLD
      @edge_density_threshold = options[:edge_density_threshold] || DEFAULT_EDGE_DENSITY_THRESHOLD
      @text_like_threshold = options[:text_like_threshold] || DEFAULT_TEXT_LIKE_THRESHOLD
      @stats = { total: 0, skipped_dark: 0, skipped_edges: 0, skipped_text: 0, passed: 0 }
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

        # Check 1: Brightness - skip if too dark
        brightness = calculate_brightness(image)
        if brightness < @brightness_threshold
          @stats[:skipped_dark] += 1
          return false
        end

        # Check 2: Edge density - skip if no edges (blurry/uniform)
        edge_density = calculate_edge_density(image)
        if edge_density < @edge_density_threshold
          @stats[:skipped_edges] += 1
          return false
        end

        # Check 3: Text-like pattern detection
        # Text typically has horizontal alignment and high contrast
        text_likelihood = calculate_text_likelihood(image)
        if text_likelihood < @text_like_threshold
          @stats[:skipped_text] += 1
          return false
        end

        @stats[:passed] += 1
        true
      rescue Vips::Error
        # If Vips fails, process the frame anyway (fail open)
        @stats[:passed] += 1
        true
      rescue StandardError
        # Any other error, process the frame
        @stats[:passed] += 1
        true
      end
    end

    def stats
      @stats.dup
    end

    def reset_stats!
      @stats = { total: 0, skipped_dark: 0, skipped_edges: 0, skipped_text: 0, passed: 0 }
    end

    def skip_rate
      return 0.0 if @stats[:total] == 0

      ((@stats[:total] - @stats[:passed]).to_f / @stats[:total]) * 100
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

      # Use Sobel operator for edge detection
      sobel = gray.sobel

      # Count strong edges (pixels with high gradient magnitude)
      total_pixels = image.width * image.height
      strong_edges = sobel.more(30).avg * total_pixels / 255.0

      strong_edges / total_pixels
    end

    def calculate_text_likelihood(image)
      return 0 if image.width == 0 || image.height == 0

      gray = image.bands == 1 ? image : image.colourspace('b-w')

      # Apply threshold to get binary image
      threshold = gray.percent(50)
      binary = gray.more(threshold)

      # Calculate horizontal projection profile
      # Text typically creates distinct peaks in horizontal projection
      horizontal_profile = binary.project('vertical')[0]

      # Check for variations in the profile (text creates alternating dark/light bands)
      profile_data = horizontal_profile.to_a
      return 0 if profile_data.length < 2

      # Calculate standard deviation - text has high variance
      mean = profile_data.sum.to_f / profile_data.length
      variance = profile_data.map { |v| (v - mean)**2 }.sum / profile_data.length
      std_dev = Math.sqrt(variance)

      # Normalize by mean to get coefficient of variation
      return 0 if mean == 0

      cv = std_dev / mean

      # Also check for horizontal edge density (text has strong horizontal components)
      horizontal_edges = gray.sobel[0].abs.more(20).avg / 255.0

      # Combine metrics
      (cv * 0.5) + (horizontal_edges * 0.5)
    end
  end
end
