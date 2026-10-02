# frozen_string_literal: true

require 'digest'

module InvasionStudio
  module Extraction
    # Uses the same OCR frames/crop as encounter detection; no second OCR pass.
    class EventMarkers
      DEATH_MESSAGE = /\b(Furled\s+Finger|Hunter)\s+(.+?)\s+has\s+died\b/i
      BANNER_GAP = 8.0

      def initialize(videos)
        @videos = videos.to_h { |video| [video.path, video] }
        @events = videos.to_h do |video|
          events = video.frames.filter_map do |frame|
            match = DEATH_MESSAGE.match(frame.text.to_s.gsub(/\s+/, ' '))
            next unless match

            { time: seconds(frame.timestamp), type: match[1].downcase == 'hunter' ? 'hunter_defeated' : 'phantom_defeated',
              label: match[2].strip[0, 500] }
          end
          [video.path, events]
        end
      end

      def for_segment(segment)
        start = seconds(segment.start_time)
        finish = seconds(segment.end_time)
        parts = if segment.start_video == segment.end_video
                  [[segment.start_video, start, finish, 0.0]]
                else
                  duration = @videos.fetch(segment.start_video).metadata.fetch(:duration).to_f
                  [[segment.start_video, start, duration, 0.0], [segment.end_video, 0.0, finish, duration - start]]
                end
        events = parts.flat_map do |path, from, to, offset|
          @events.fetch(path).filter_map do |event|
            event.merge(time: event[:time] - from + offset) if event[:time] >= from && event[:time] < to
          end
        end.sort_by { |event| event[:time] }
        last_seen = {}
        events.filter_map do |event|
          identity = [event[:type], event[:label].downcase]
          previous = last_seen[identity]
          last_seen[identity] = event[:time]
          next if previous && event[:time] - previous <= BANNER_GAP

          time = event[:time].round(3)
          { 'id' => "ocr-#{Digest::SHA256.hexdigest([*identity, time].join('|'))[0, 32]}",
            'time' => time, 'event_type' => event[:type], 'label' => event[:label] }
        end
      end

      private

      def seconds(timestamp)
        hours, minutes, seconds = timestamp.split(':').map(&:to_f)
        hours * 3600 + minutes * 60 + seconds
      end
    end
  end
end
