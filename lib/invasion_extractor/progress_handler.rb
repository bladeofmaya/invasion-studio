require 'ruby-progressbar'

module InvasionExtractor
  class ProgressHandler
    def initialize(options = {})
      @enabled = options.fetch(:enabled, true)
      @bars = {}
    end

    def create_callback
      return nil unless @enabled

      lambda { |event, current, total|
        handle_event(event, current, total)
      }
    end

    def handle_event(event, current, total)
      return unless @enabled

      bar = @bars[event] ||= create_progress_bar(event, total)

      bar.total = total if bar.total != total
      bar.progress = current

      return unless current >= total

      bar.finish
      @bars.delete(event)
    end

    def finish_all
      @bars.each_value(&:finish)
      @bars.clear
    end

    private

    def create_progress_bar(event, total)
      title = format_title(event)

      ProgressBar.create(
        title: title,
        total: total,
        format: '%t: |%B| %p%% %e',
        progress_mark: '█',
        remainder_mark: '░',
        throttle_rate: 0.1
      )
    end

    def format_title(event)
      case event
      when :extracting_frames
        'Extracting frames'
      when :processing_ocr
        'Processing OCR'
      when :generating_clip
        'Generating clips'
      else
        event.to_s.gsub('_', ' ').capitalize
      end
    end
  end
end
