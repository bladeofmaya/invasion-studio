# frozen_string_literal: true

module InvasionStudio
  module Webui
    class FileOpener
      def initialize(process_runner: ProcessRunner.new, platform: RbConfig::CONFIG['host_os'])
        @process_runner = process_runner
        @platform = platform
      end

      def open(path)
        command = @platform.match?(/darwin/) ? 'open' : 'xdg-open'
        @process_runner.run(command, path)
      end
    end
  end
end
