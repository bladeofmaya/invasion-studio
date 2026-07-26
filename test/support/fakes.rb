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

  class FakeClipRepository
    def initialize(folder_path, clips)
      @folder_path = File.expand_path(folder_path)
      @clips = clips
    end

    def find(id)
      @clips.find { |clip| clip['id'] == id }
    end

    def path_for(clip)
      resolve(clip['path'])
    end

    def resolve(path)
      return nil if path.nil? || path.empty?

      expanded = File.expand_path(path, @folder_path)
      return nil unless expanded.start_with?("#{@folder_path}#{File::SEPARATOR}")

      expanded
    end

    def relative_path(path)
      path.to_s.delete_prefix("#{@folder_path}#{File::SEPARATOR}")
    end
  end
end
