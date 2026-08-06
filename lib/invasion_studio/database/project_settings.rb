# frozen_string_literal: true

module InvasionStudio
  module Database
    class ProjectSettings
      DEFAULT_VIDEO_SETTINGS = {
        'audio_track_count' => 4,
        'default_audio_track' => 4
      }.freeze
      MAX_AUDIO_TRACKS = 32

      def initialize(database)
        @metadata = database[:project_metadata]
      end

      def video
        DEFAULT_VIDEO_SETTINGS.to_h do |name, default|
          value = @metadata.where(key: key_for(name)).get(:value)
          [name, value ? value.to_i : default]
        end
      end

      def update_video(audio_track_count:, default_audio_track:)
        return false unless valid_video_settings?(audio_track_count, default_audio_track)

        now = Time.now.utc.iso8601
        settings = {
          'audio_track_count' => audio_track_count,
          'default_audio_track' => default_audio_track
        }
        @metadata.db.transaction do
          settings.each do |name, value|
            @metadata.insert_conflict(
              target: :key,
              update: { value: value.to_s, updated_at: now }
            ).insert(key: key_for(name), value: value.to_s, created_at: now, updated_at: now)
          end
        end
        true
      end

      private

      def key_for(name)
        "video.#{name}"
      end

      def valid_video_settings?(count, default_track)
        count.is_a?(Integer) && default_track.is_a?(Integer) &&
          count.between?(1, MAX_AUDIO_TRACKS) && default_track.between?(1, count)
      end
    end
  end
end
