module InvasionExtractor
  module Commands
    class Base
      attr_reader :options, :argv

      def initialize(options, argv)
        @options = options
        @argv = argv
      end

      def run
        raise NotImplementedError, "#{self.class} must implement #run"
      end
    end
  end
end
