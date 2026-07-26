# frozen_string_literal: true

module InvasionStudio
  module Kdenlive
    class MediaChains
      def initialize(context)
        @context = context
      end

      def to_xml
        black_producer + @context.chain_count.times.map { |index| chain(index) }.join
      end

      private

      def black_producer
        <<~XML.gsub(/^/, '  ')
          <producer id="producer0" in="00:00:00.000" out="#{@context.duration_timecode}">
            <property name="length">2147483647</property>
            <property name="eof">continue</property>
            <property name="resource">black</property>
            <property name="aspect_ratio">1</property>
            <property name="mlt_service">color</property>
            <property name="kdenlive:playlistid">black_track</property>
            <property name="mlt_image_format">rgba</property>
            <property name="set.test_audio">0</property>
          </producer>
        XML
      end

      def chain(index)
        xml = +<<~XML.gsub(/^/, '  ')
          <chain id="chain#{index}" out="#{@context.duration_timecode}">
            <property name="length">#{@context.duration_frames}</property>
            <property name="eof">pause</property>
            <property name="resource">#{@context.escape(@context.basename)}</property>
            <property name="mlt_service">avformat-novalidate</property>
            <property name="seekable">1</property>
            <property name="kdenlive:folderid">-1</property>
            <property name="kdenlive:id">1</property>
            <property name="kdenlive:control_uuid">#{@context.control_uuid}</property>
            <property name="mute_on_pause">0</property>
            <property name="kdenlive:clip_type">0</property>
        XML
        xml << stream_selection(index)
        xml << "  </chain>\n"
        xml
      end

      def stream_selection(index)
        if index < @context.audio_stream_count
          <<~XML.gsub(/^/, '    ')
            <property name="video_index">-1</property>
            <property name="audio_index">#{@context.audio_stream_count - index}</property>
            <property name="astream">#{@context.audio_stream_count - index - 1}</property>
            <property name="set.test_image">1</property>
          XML
        elsif index == @context.video_chain_index
          <<~XML.gsub(/^/, '    ')
            <property name="audio_index">-1</property>
            <property name="video_index">0</property>
            <property name="vstream">0</property>
            <property name="set.test_audio">1</property>
          XML
        else
          ''
        end
      end
    end
  end
end
