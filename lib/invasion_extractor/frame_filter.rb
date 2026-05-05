require 'vips'

module InvasionExtractor
  class FrameFilter
    # Thresholds tuned for white-on-black text (Elden Ring UI)
    DEFAULT_BRIGHT_PIXEL_THRESHOLD = 200   # Pixels brighter than this count as "text"
    DEFAULT_MIN_BRIGHT_RATIO = 0.005       # At least 0.5% bright pixels (empty = 0%)
    DEFAULT_MAX_BRIGHT_RATIO = 0.35        # Less than 35% bright pixels (UI overlay >50%)
    DEFAULT_MIN_TEXT_BAND_PIXELS = 20      # A text row has at least 20 bright pixels
    DEFAULT_MIN_BAND_HEIGHT = 2            # Text bands are at least 2px tall (noise is 1px)
    DEFAULT_MIN_TEXT_BANDS = 1             # Need at least 1 text band

    attr_reader :enabled

    def initialize(options = {})
      @enabled = options.fetch(:enabled, false)
      @bright_threshold = options[:bright_threshold] || DEFAULT_BRIGHT_PIXEL_THRESHOLD
      @min_bright_ratio = options[:min_bright_ratio] || DEFAULT_MIN_BRIGHT_RATIO
      @max_bright_ratio = options[:max_bright_ratio] || DEFAULT_MAX_BRIGHT_RATIO
      @min_band_pixels = options[:min_band_pixels] || DEFAULT_MIN_TEXT_BAND_PIXELS
      @min_band_height = options[:min_band_height] || DEFAULT_MIN_BAND_HEIGHT
      @min_bands = options[:min_bands] || DEFAULT_MIN_TEXT_BANDS
      @stats = { total: 0, skipped_empty: 0, skipped_overlay: 0, skipped_nobands: 0, passed: 0 }
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
        gray = image.bands == 1 ? image : image.colourspace('b-w')

        # Check 1: Bright pixel ratio
        # Empty frames have ~0%, text frames have 1-15%, UI overlays have >35%
        bright_ratio = calculate_bright_ratio(gray)

        if bright_ratio < @min_bright_ratio
          @stats[:skipped_empty] += 1
          return false
        end

        if bright_ratio > @max_bright_ratio
          @stats[:skipped_overlay] += 1
          return false
        end

        # Check 2: Text band detection
        # Text creates horizontal bands of concentrated bright pixels
        text_bands = count_text_bands(gray)

        if text_bands < @min_bands
          @stats[:skipped_nobands] += 1
          return false
        end

        @stats[:passed] += 1
        true
      rescue Vips::Error
        @stats[:passed] += 1
        true
      rescue StandardError
        @stats[:passed] += 1
        true
      end
    end

    def stats
      @stats.dup
    end

    def reset_stats!
      @stats = { total: 0, skipped_empty: 0, skipped_overlay: 0, skipped_nobands: 0, passed: 0 }
    end

    def skip_rate
      return 0.0 if @stats[:total] == 0

      ((@stats[:total] - @stats[:passed]).to_f / @stats[:total]) * 100
    end

    private

    def calculate_bright_ratio(gray)
      return 0.0 if gray.width == 0 || gray.height == 0

      total_pixels = gray.width * gray.height

      # Create binary mask: 255 for pixels above threshold, 0 otherwise
      mask = gray > @bright_threshold
      bright_pixels = mask.avg / 255.0 * total_pixels
      bright_pixels.to_f / total_pixels
    end

    def count_text_bands(gray)
      return 0 if gray.width == 0 || gray.height == 0

      # Create binary mask of bright pixels
      mask = gray > @bright_threshold

      # Project: sum bright pixels per row (vertical projection)
      row_sums = mask.project[1].to_a.flatten

      # Count contiguous bands of rows with enough bright pixels
      # Only count bands that are at least @min_band_height pixels tall
      text_bands = 0
      band_height = 0

      row_sums.each do |count|
        if count >= @min_band_pixels
          band_height += 1
        else
          text_bands += 1 if band_height >= @min_band_height
          band_height = 0
        end
      end

      # Check final band
      text_bands += 1 if band_height >= @min_band_height

      text_bands
    end
  end
end
