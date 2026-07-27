# frozen_string_literal: true

module InvasionStudio
  module Webui
    class FileOpener
      LINUX_FOLDER_COMMANDS = [
        'nautilus',
        'dolphin'
      ].freeze

      def initialize(process_runner: ProcessRunner.new, platform: RbConfig::CONFIG['host_os'])
        @process_runner = process_runner
        @platform = platform
      end

      def open(path)
        return @process_runner.run('open', path) if @platform.match?(/darwin/)

        @process_runner.run('xdg-open', path)
      end

      def reveal(path)
        return @process_runner.run('open', '-R', path) if @platform.match?(/darwin/)

        directory = File.dirname(path)
        return true if @platform.match?(/linux/) && open_folder_with_file_manager(directory)

        @process_runner.run('xdg-open', directory)
      end

      private

      def open_folder_with_file_manager(directory)
        LINUX_FOLDER_COMMANDS.each do |binary|
          next unless executable?(binary)

          return true if @process_runner.run(binary, directory)
        end
        false
      end

      def executable?(name)
        ENV['PATH'].to_s.split(File::PATH_SEPARATOR).any? do |dir|
          candidate = File.join(dir, name)
          File.file?(candidate) && File.executable?(candidate)
        end
      end
    end
  end
end
