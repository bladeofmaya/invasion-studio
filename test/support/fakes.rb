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

  class FakeStorage
    def initialize(folder_path, files = {})
      @folder_path = File.expand_path(folder_path)
      @files = files
    end

    def resolve(key)
      return nil if key.nil? || key.empty?

      expanded = File.expand_path(key, @folder_path)
      return nil unless expanded.start_with?("#{@folder_path}#{File::SEPARATOR}")

      expanded
    end

    def exist?(key)
      path = resolve(key)
      path && File.exist?(path)
    end

    def relative_path(path)
      path.to_s.delete_prefix("#{@folder_path}#{File::SEPARATOR}")
    end

    def move(source_key, destination_key)
      source = resolve(source_key)
      destination = resolve(destination_key)
      return nil unless source && destination
      return nil unless File.exist?(source)

      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.mv(source, destination)
      destination_key
    end

    def store(source_path, key)
      destination = resolve(key)
      return nil unless destination

      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source_path, destination)
      key
    end

    def delete(key)
      path = resolve(key)
      return false unless path

      FileUtils.rm_f(path)
      true
    end
  end
end
