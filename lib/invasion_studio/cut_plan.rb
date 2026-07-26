# frozen_string_literal: true

module InvasionStudio
  class CutPlan
    attr_reader :cuts

    def self.build(cuts)
      normalized = normalize(cuts)
      normalized && new(normalized)
    end

    def self.empty
      new([])
    end

    def initialize(cuts)
      @cuts = cuts.map(&:freeze).freeze
      freeze
    end

    def effective_duration(media_duration)
      duration = duration_value(media_duration)
      return 0.0 unless duration

      [duration - removed_duration(duration), 0.0].max
    end

    def keep_segments(media_duration)
      duration = duration_value(media_duration)
      return [] unless duration

      segments = []
      position = 0.0
      @cuts.each do |cut|
        cut_start = [cut['start'], duration].min
        cut_end = [cut['end'], duration].min
        segments << { start: position, end: cut_start } if position < cut_start
        position = [position, cut_end].max
      end
      segments << { start: position, end: duration } if position < duration
      segments
    end

    class << self
      private

      def normalize(cuts)
        return nil unless cuts.is_a?(Array)

        normalized = cuts.map do |cut|
          return nil unless cut.respond_to?(:[])

          start_time = Float(cut['start'] || cut[:start], exception: false)
          end_time = Float(cut['end'] || cut[:end], exception: false)
          return nil unless start_time&.finite? && end_time&.finite?
          return nil if start_time.negative? || start_time >= end_time

          { 'start' => start_time, 'end' => end_time }
        end.sort_by { |cut| cut['start'] }

        normalized.each_with_object([]) do |cut, merged|
          if merged.any? && cut['start'] <= merged.last['end']
            merged.last['end'] = [merged.last['end'], cut['end']].max
          else
            merged << cut
          end
        end
      end
    end

    private

    def duration_value(value)
      duration = Float(value, exception: false)
      duration if duration&.positive?
    end

    def removed_duration(duration)
      @cuts.sum do |cut|
        start_time = [cut['start'], duration].min
        end_time = [cut['end'], duration].min
        end_time > start_time ? end_time - start_time : 0.0
      end
    end
  end
end
