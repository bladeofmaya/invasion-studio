# frozen_string_literal: true

require 'cgi'
require 'securerandom'

module InvasionStudio
  module Kdenlive
    class BuildContext
      attr_reader :folder_path, :video_path, :metadata, :width, :height, :fps,
                  :duration_frames, :duration_timecode, :sequence_uuid, :document_uuid,
                  :control_uuid, :session_id, :document_id, :audio_stream_count

      def initialize(folder_path:, video_path:, metadata:, width:, height:,
                     uuid_factory: -> { "{#{SecureRandom.uuid}}" }, clock: -> { Time.now })
        @folder_path = File.expand_path(folder_path)
        @video_path = video_path
        @metadata = metadata
        @width = width
        @height = height
        @fps = metadata[:fps] || 30
        @audio_stream_count = metadata.fetch(:audio_stream_count, 4)
        @duration_frames = (metadata[:duration] * @fps).round
        @duration_timecode = timecode(@duration_frames)
        @sequence_uuid = uuid_factory.call
        @document_uuid = uuid_factory.call
        @control_uuid = uuid_factory.call
        @session_id = uuid_factory.call
        @document_id = (clock.call.to_f * 1000).to_i.to_s
      end

      def basename
        File.basename(@video_path)
      end

      def profile_name
        "#{@width}x#{@height}_#{@fps}fps"
      end

      def sequence_duration_timecode
        timecode(@duration_frames + 1)
      end

      def video_track_index = @audio_stream_count
      def empty_video_track_index = @audio_stream_count + 1
      def video_chain_index = @audio_stream_count
      def bin_chain_index = @audio_stream_count + 1
      def chain_count = @audio_stream_count + 2
      def track_count = @audio_stream_count + 2
      def video_playlist_index = @audio_stream_count * 2
      def filter_count = @audio_stream_count * 3

      def timecode(frames)
        return '00:00:00.000' if frames <= 0

        seconds = frames.to_f / @fps
        hours = (seconds / 3600).to_i
        minutes = ((seconds % 3600) / 60).to_i
        secs = (seconds % 60).to_i
        millis = ((seconds % 1) * 1000).round
        format('%02d:%02d:%02d.%03d', hours, minutes, secs, millis)
      end

      def escape(value)
        CGI.escapeHTML(value.to_s)
      end
    end
  end
end
