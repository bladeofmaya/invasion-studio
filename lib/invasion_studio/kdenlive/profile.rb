# frozen_string_literal: true

module InvasionStudio
  module Kdenlive
    class Profile
      def initialize(context)
        @context = context
      end

      def to_xml
        aspect_gcd = @context.width.gcd(@context.height)
        aspect_width = @context.width / aspect_gcd
        aspect_height = @context.height / aspect_gcd
        %Q{  <profile description="Auto #{@context.width}x#{@context.height} #{@context.fps} fps" width="#{@context.width}" height="#{@context.height}" progressive="1" sample_aspect_num="1" sample_aspect_den="1" display_aspect_num="#{aspect_width}" display_aspect_den="#{aspect_height}" frame_rate_num="#{@context.fps}" frame_rate_den="1" colorspace="709"/>\n}
      end
    end
  end
end
