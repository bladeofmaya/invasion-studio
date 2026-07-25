# frozen_string_literal: true

require 'open3'

module InvasionStudio
  class ProcessRunner
    Result = Data.define(:stdout, :stderr, :status) do
      def success?
        status.success?
      end
    end

    def capture(*command)
      stdout, stderr, status = Open3.capture3(*command)
      Result.new(stdout:, stderr:, status:)
    rescue Errno::ENOENT => e
      raise Error, "Required executable not found: #{command.first} (#{e.message})"
    end

    def run(*command, log_path: nil)
      if log_path
        File.open(log_path, 'a') do |log|
          status = system(*command, out: log, err: [:child, :out])
          return status && $CHILD_STATUS.success?
        end
      end

      system(*command) && $CHILD_STATUS.success?
    rescue Errno::ENOENT => e
      raise Error, "Required executable not found: #{command.first} (#{e.message})"
    end
  end
end
