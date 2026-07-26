# frozen_string_literal: true

module InvasionStudio
  module Webui
    class FileOpener
      def initialize(process_runner: ProcessRunner.new, platform: RbConfig::CONFIG['host_os'])
        @process_runner = process_runner
        @platform = platform
      end

      def reveal(path)
        return @process_runner.run('open', '-R', path) if @platform.match?(/darwin/)

        @process_runner.run('xdg-open', File.dirname(path))
      end
    end
  end
end
