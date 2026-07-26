require 'json'

module InvasionStudio
  module Kdenlive
    class Sequence
      def initialize(context)
        @context = context
      end

      def to_xml
        <<~XML
          <tractor id="#{context.sequence_uuid}" in="00:00:00.000" out="#{context.duration_timecode}">
            <property name="kdenlive:uuid">#{context.sequence_uuid}</property>
            <property name="kdenlive:clipname">Sequence 1</property>
            <property name="kdenlive:sequenceproperties.hasAudio">1</property>
            <property name="kdenlive:sequenceproperties.hasVideo">1</property>
            <property name="kdenlive:sequenceproperties.activeTrack">#{context.video_track_index}</property>
            <property name="kdenlive:sequenceproperties.tracksCount">#{context.track_count}</property>
            <property name="kdenlive:sequenceproperties.documentuuid">#{context.sequence_uuid}</property>
            <property name="kdenlive:control_uuid">#{context.sequence_uuid}</property>
            <property name="kdenlive:duration">#{context.sequence_duration_timecode}</property>
            <property name="kdenlive:maxduration">#{context.duration_frames}</property>
            <property name="kdenlive:producer_type">17</property>
            <property name="kdenlive:id">3</property>
            <property name="kdenlive:clip_type">0</property>
            <property name="kdenlive:file_size">0</property>
            <property name="kdenlive:folderid">2</property>
            <property name="kdenlive:sequenceproperties.audioTarget">1</property>
            <property name="kdenlive:sequenceproperties.videoTarget">2</property>
            <property name="kdenlive:sequenceproperties.tracks">4</property>
            <property name="kdenlive:sequenceproperties.groups">#{JSON.pretty_generate(groups)}
          </property>
            <property name="kdenlive:sequenceproperties.guides">[
          ]
          </property>
          #{tracks}#{transitions}#{filters}  </tractor>
        XML
      end

      private

      attr_reader :context

      def groups
        [{
          'children' => (0..context.video_track_index).map { |index| { 'data' => "#{index}:0:-1", 'leaf' => 'clip', 'type' => 'Leaf' } },
          'type' => 'AVSplit'
        }]
      end

      def tracks
        producers = ['producer0'] + context.track_count.times.map { |index| "tractor#{index}" }
        producers.map { |producer| "  <track producer=\"#{producer}\"/>\n" }.join
      end

      def transitions
        audio = context.audio_stream_count.times.map do |index|
          <<~XML
              <transition id="transition#{index}">
                <property name="a_track">0</property>
                <property name="b_track">#{index + 1}</property>
                <property name="mlt_service">mix</property>
                <property name="kdenlive_id">mix</property>
                <property name="internal_added">237</property>
                <property name="always_active">1</property>
                <property name="accepts_blanks">1</property>
                <property name="sum">1</property>
              </transition>
          XML
        end
        video = 2.times.map do |index|
          <<~XML
              <transition id="transition#{index + context.audio_stream_count}">
                <property name="a_track">0</property>
                <property name="b_track">#{index + context.audio_stream_count + 1}</property>
                <property name="compositing">0</property>
                <property name="distort">0</property>
                <property name="rotate_center">0</property>
                <property name="mlt_service">qtblend</property>
                <property name="kdenlive_id">qtblend</property>
                <property name="internal_added">237</property>
                <property name="always_active">1</property>
              </transition>
          XML
        end
        (audio + video).join
      end

      def filters
        <<~XML
            <filter id="filter#{context.filter_count}">
              <property name="window">75</property>
              <property name="max_gain">20dB</property>
              <property name="channel_mask">-1</property>
              <property name="mlt_service">volume</property>
              <property name="internal_added">237</property>
              <property name="disable">1</property>
            </filter>
            <filter id="filter#{context.filter_count + 1}">
              <property name="channel">-1</property>
              <property name="mlt_service">panner</property>
              <property name="internal_added">237</property>
              <property name="start">0.5</property>
              <property name="disable">1</property>
            </filter>
        XML
      end
    end
  end
end
