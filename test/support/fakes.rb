# frozen_string_literal: true

module TestSupport
  class SuccessfulStatus
    def success?
      true
    end
  end

  class FailedStatus
    def success?
      false
    end
  end

  class FakeProcessRunner
    attr_reader :commands

    def initialize(success: true, stdout: '', stderr: '')
      @success = success
      @stdout = stdout
      @stderr = stderr
      @commands = []
    end

    def run(*command, **options)
      @commands << { type: :run, command: command, options: options }
      @success
    end

    def capture(*command)
      @commands << { type: :capture, command: command, options: {} }
      status = @success ? SuccessfulStatus.new : FailedStatus.new
      InvasionStudio::ProcessRunner::Result.new(stdout: @stdout, stderr: @stderr, status: status)
    end
  end

  FakeMetadataProbe = Data.define(:metadata)
end
