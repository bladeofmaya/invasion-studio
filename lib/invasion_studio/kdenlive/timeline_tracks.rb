# frozen_string_literal: true

module InvasionStudio
  module Kdenlive
    class TimelineTracks
      def initialize(context)
        @context = context
      end

      def to_xml
        audio_playlists + video_playlists + audio_tractors + video_tractors
      end

      private

      def audio_playlists
        @context.audio_stream_count.times.map do |index|
          playlist = index * 2
          <<~XML.gsub(/^/, '  ')
            <playlist id="playlist#{playlist}">
              <property name="kdenlive:audio_track">1</property>
              <entry in="00:00:00.000" out="#{@context.duration_timecode}" producer="chain#{index}">
                <property name="kdenlive:id">1</property>
              </entry>
            </playlist>
            <playlist id="playlist#{playlist + 1}">
              <property name="kdenlive:audio_track">1</property>
            </playlist>
          XML
        end.join
      end

      def video_playlists
        <<~XML.gsub(/^/, '  ')
          <playlist id="playlist#{@context.video_playlist_index}">
            <entry in="00:00:00.000" out="#{@context.duration_timecode}" producer="chain#{@context.video_chain_index}">
              <property name="kdenlive:id">1</property>
            </entry>
          </playlist>
          <playlist id="playlist#{@context.video_playlist_index + 1}"/>
          <playlist id="playlist#{@context.video_playlist_index + 2}"/>
          <playlist id="playlist#{@context.video_playlist_index + 3}"/>
        XML
      end

      def audio_tractors
        @context.audio_stream_count.times.map { |index| audio_tractor(index) }.join
      end

      def audio_tractor(index)
        <<~XML.gsub(/^/, '  ')
          <tractor id="tractor#{index}" in="00:00:00.000" out="#{@context.duration_timecode}">
            <property name="kdenlive:audio_track">1</property>
            <property name="kdenlive:trackheight">75</property>
            <property name="kdenlive:timeline_active">1</property>
            <track hide="video" producer="playlist#{index * 2}"/>
            <track hide="video" producer="playlist#{index * 2 + 1}"/>
            #{volume_filter(index * 3).strip}
            #{panner_filter(index * 3 + 1).strip}
            #{audio_level_filter(index * 3 + 2).strip}
          </tractor>
        XML
      end

      def volume_filter(id)
        <<~XML
          <filter id="filter#{id}">
            <property name="window">75</property>
            <property name="max_gain">20dB</property>
            <property name="channel_mask">-1</property>
            <property name="mlt_service">volume</property>
            <property name="internal_added">237</property>
            <property name="disable">1</property>
          </filter>
        XML
      end

      def panner_filter(id)
        <<~XML
          <filter id="filter#{id}">
            <property name="channel">-1</property>
            <property name="mlt_service">panner</property>
            <property name="internal_added">237</property>
            <property name="start">0.5</property>
            <property name="disable">1</property>
          </filter>
        XML
      end

      def audio_level_filter(id)
        <<~XML
          <filter id="filter#{id}">
            <property name="iec_scale">0</property>
            <property name="mlt_service">audiolevel</property>
            <property name="internal_added">237</property>
            <property name="dbpeak">1</property>
            <property name="disable">1</property>
          </filter>
        XML
      end

      def video_tractors
        <<~XML.gsub(/^/, '  ')
          <tractor id="tractor#{@context.video_track_index}" in="00:00:00.000" out="#{@context.duration_timecode}">
            <property name="kdenlive:trackheight">75</property>
            <property name="kdenlive:timeline_active">1</property>
            <track hide="audio" producer="playlist#{@context.video_playlist_index}"/>
            <track hide="audio" producer="playlist#{@context.video_playlist_index + 1}"/>
          </tractor>
          <tractor id="tractor#{@context.empty_video_track_index}" in="00:00:00.000">
            <property name="kdenlive:trackheight">75</property>
            <property name="kdenlive:timeline_active">1</property>
            <track hide="audio" producer="playlist#{@context.video_playlist_index + 2}"/>
            <track hide="audio" producer="playlist#{@context.video_playlist_index + 3}"/>
          </tractor>
        XML
      end
    end
  end
end
