# frozen_string_literal: true

module InvasionStudio
  module ClipMarkers
    EVENT_TYPES = %w[custom phantom_defeated hunter_defeated invader_defeated host_defeated invasion_start invasion_end].freeze

    def self.merge_detected(existing, detected)
      detected.reduce(existing.dup) do |result, marker|
        duplicate = result.any? do |saved|
          saved['id'] == marker['id'] ||
            (saved['event_type'] == marker['event_type'] && (saved['time'] - marker['time']).abs <= 2.0 &&
             saved['label'].to_s.strip.downcase == marker['label'].to_s.strip.downcase)
        end
        result << marker unless duplicate
        result
      end
    end

    def self.normalize(markers, duration: nil)
      return nil unless markers.is_a?(Array) && markers.length <= 1000

      ids = []
      markers.map do |marker|
        return nil unless marker.is_a?(Hash)

        id, time, type, label = marker.values_at('id', 'time', 'event_type', 'label')
        label = '' if label.nil?
        return nil unless id.is_a?(String) && id.match?(/\A[\w-]{1,80}\z/) && !ids.include?(id)
        return nil unless time.is_a?(Numeric) && time.finite? && time >= 0
        return nil if duration && duration.positive? && time > duration
        return nil unless EVENT_TYPES.include?(type) && label.is_a?(String) && label.length <= 500

        ids << id
        { 'id' => id, 'time' => time.to_f, 'event_type' => type, 'label' => label }
      end.sort_by { |marker| [marker['time'], marker['id']] }
    end

    def self.after_cuts(markers, plan)
      markers.filter_map do |marker|
        time = marker['time']
        next if plan.cuts.any? { |cut| time >= cut['start'] && time < cut['end'] }

        removed = plan.cuts.sum { |cut| cut['end'] <= time ? cut['end'] - cut['start'] : 0.0 }
        marker.merge('time' => time - removed)
      end
    end
  end
end
