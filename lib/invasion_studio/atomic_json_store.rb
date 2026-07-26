# frozen_string_literal: true

require 'json'
require 'securerandom'

module InvasionStudio
  class AtomicJsonStore
    def initialize(path)
      @path = path
    end

    def exist?
      File.exist?(@path)
    end

    def read
      JSON.parse(File.read(@path))
    end

    def write(data)
      serialized = JSON.pretty_generate(data)
      temporary = File.join(
        File.dirname(@path),
        ".#{File.basename(@path)}.#{Process.pid}.#{SecureRandom.hex(6)}.tmp"
      )
      File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        file.write(serialized)
        file.flush
        file.fsync
      end
      File.rename(temporary, @path)
      true
    ensure
      File.delete(temporary) if temporary && File.exist?(temporary)
    end
  end
end
