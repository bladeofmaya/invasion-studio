# frozen_string_literal: true

module InvasionStudio
  module Storage
    class Adapter
      class NotImplementedError < InvasionStudio::Error; end

      def store(_source_path, _key)
        raise NotImplementedError
      end

      def move(_source_key, _destination_key)
        raise NotImplementedError
      end

      def delete(_key)
        raise NotImplementedError
      end

      def resolve(_key)
        raise NotImplementedError
      end

      def exist?(_key)
        raise NotImplementedError
      end

      def relative_path(_path)
        raise NotImplementedError
      end

      def url(_key)
        nil
      end
    end
  end
end
