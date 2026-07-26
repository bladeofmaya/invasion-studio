module InvasionStudio
  module Kdenlive
    class DocumentBuilder
      COMPONENTS = [Profile, MediaChains, TimelineTracks, Sequence, ProjectBin].freeze

      def initialize(folder_path:, width:, height:, uuid_factory: nil, clock: nil)
        @folder_path = folder_path
        @width = width
        @height = height
        @uuid_factory = uuid_factory
        @clock = clock
      end

      def build(video_path, metadata)
        context = build_context(video_path, metadata)
        body = COMPONENTS.map { |component| component.new(context).to_xml }.join

        <<~XML
          <?xml version='1.0' encoding='utf-8'?>
          <mlt LC_NUMERIC="C" producer="main_bin" root="#{context.escape(File.expand_path(@folder_path))}" version="7.38.0">
          #{indent(body)}
          </mlt>
        XML
      end

      private

      def build_context(video_path, metadata)
        arguments = {
          folder_path: @folder_path,
          video_path: video_path,
          metadata: metadata,
          width: @width,
          height: @height
        }
        arguments[:uuid_factory] = @uuid_factory if @uuid_factory
        arguments[:clock] = @clock if @clock
        BuildContext.new(**arguments)
      end

      def indent(xml)
        xml.lines.map { |line| "  #{line}" }.join.rstrip
      end
    end
  end
end
