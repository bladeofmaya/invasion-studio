require 'json'

module InvasionStudio
  module Kdenlive
    class ProjectBin
      GUIDE_COLORS = %w[#9b59b6 #3daee9 #1abc9c #1cdc9a #c9ce3b #fdbc4b #f39c1f #f47750 #da4453].freeze

      def initialize(context)
        @context = context
      end

      def to_xml
        <<~XML
          <playlist id="main_bin">
            <property name="kdenlive:folder.-1.2">Sequences</property>
            <property name="kdenlive:sequenceFolder">2</property>
            <property name="kdenlive:docproperties.audioChannels">2</property>
            <property name="kdenlive:docproperties.binsort">0</property>
            <property name="kdenlive:docproperties.browserurl"/>
            <property name="kdenlive:docproperties.documentid">#{context.document_id}</property>
            <property name="kdenlive:docproperties.enableTimelineZone">0</property>
            <property name="kdenlive:docproperties.enableexternalproxy">0</property>
            <property name="kdenlive:docproperties.enableproxy">0</property>
            <property name="kdenlive:docproperties.externalproxyparams"/>
            <property name="kdenlive:docproperties.generateimageproxy">0</property>
            <property name="kdenlive:docproperties.generateproxy">0</property>
            <property name="kdenlive:docproperties.guidesCategories">#{JSON.pretty_generate(guides)}
          </property>
            <property name="kdenlive:docproperties.kdenliveversion">26.04.1</property>
            <property name="kdenlive:docproperties.previewextension"/>
            <property name="kdenlive:docproperties.previewparameters"/>
            <property name="kdenlive:docproperties.profile">#{context.profile_name}</property>
            <property name="kdenlive:docproperties.proxyextension"/>
            <property name="kdenlive:docproperties.proxyimageminsize">2000</property>
            <property name="kdenlive:docproperties.proxyimagesize">800</property>
            <property name="kdenlive:docproperties.proxyminsize">1000</property>
            <property name="kdenlive:docproperties.proxyparams"/>
            <property name="kdenlive:docproperties.proxyresize">640</property>
            <property name="kdenlive:docproperties.seekOffset">30000</property>
            <property name="kdenlive:docproperties.sessionid">#{context.session_id}</property>
            <property name="kdenlive:docproperties.uuid">#{context.document_uuid}</property>
            <property name="kdenlive:docproperties.version">1.1</property>
            <property name="kdenlive:expandedFolders"/>
            <property name="kdenlive:binZoom">4</property>
            <property name="kdenlive:extraBins">project_bin:-1:0</property>
            <property name="kdenlive:documentnotes"/>
            <property name="kdenlive:documentnotesversion">2</property>
            <property name="kdenlive:docproperties.opensequences">#{context.sequence_uuid}</property>
            <property name="kdenlive:docproperties.activetimeline">#{context.sequence_uuid}</property>
            <property name="xml_retain">1</property>
            <entry in="00:00:00.000" out="00:00:00.000" producer="#{context.sequence_uuid}"/>
            <entry in="00:00:00.000" out="#{context.duration_timecode}" producer="chain#{context.bin_chain_index}"/>
          </playlist>
          <tractor id="tractor_project" in="00:00:00.000" out="#{context.duration_timecode}">
            <property name="kdenlive:projectTractor">1</property>
            <track in="00:00:00.000" out="#{context.duration_timecode}" producer="#{context.sequence_uuid}"/>
          </tractor>
        XML
      end

      private

      attr_reader :context

      def guides
        GUIDE_COLORS.each_with_index.map do |color, index|
          { 'color' => color, 'comment' => "Category #{index + 1}", 'index' => index }
        end
      end
    end
  end
end
