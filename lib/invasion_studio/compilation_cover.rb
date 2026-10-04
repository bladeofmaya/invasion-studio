# frozen_string_literal: true

require 'securerandom'

module InvasionStudio
  class CompilationCover
    MAX_BYTES = 10 * 1024 * 1024

    def initialize(project)
      @project = project
    end

    def replace(name, file)
      group = @project.groups.find { |item| item['name'] == name }
      return false unless group
      raise Error, 'Choose a PNG, JPEG or WebP image up to 10 MB' unless file && file.size.between?(1, MAX_BYTES)
      header = File.binread(file.path, 16)
      extension = if header.start_with?("\x89PNG\r\n\x1a\n".b)
                    'png'
                  elsif header.start_with?("\xff\xd8\xff".b)
                    'jpg'
                  elsif header.start_with?('RIFF') && header.byteslice(8, 4) == 'WEBP'
                    'webp'
                  end
      raise Error, 'Choose a PNG, JPEG or WebP image' unless extension
      key = "covers/#{SecureRandom.uuid}.#{extension}"
      begin
        raise Error, 'Could not store cover image' unless @project.storage.store(file.path, key)
        saved = @project.update_group_details(name, cover_path: key)
      rescue StandardError
        @project.storage.delete(key)
        raise
      end
      unless saved
        @project.storage.delete(key)
        return false
      end
      @project.storage.delete(group['cover_path']) unless group['cover_path'].to_s.empty?
      true
    end

    def remove(name)
      group = @project.groups.find { |item| item['name'] == name }
      return false unless group
      return false unless @project.update_group_details(name, cover_path: '')
      @project.storage.delete(group['cover_path']) unless group['cover_path'].to_s.empty?
      true
    end
  end
end
