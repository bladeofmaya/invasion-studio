module InvasionExtractor
  module OCR
    class Provider
      def recognize(image_path)
        raise NotImplementedError, "#{self.class} must implement #recognize(image_path)"
      end

      def name
        class_name = self.class.name.split('::').last
        class_name.gsub(/Provider$/, '').downcase
      end
    end
  end
end
