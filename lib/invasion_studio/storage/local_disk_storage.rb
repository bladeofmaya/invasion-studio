# frozen_string_literal: true

require 'fileutils'

module InvasionStudio
  module Storage
    class LocalDiskStorage < Adapter
      def initialize(folder_path)
        @folder_path = File.expand_path(folder_path)
      end

      def store(source_path, key)
        destination = resolve(key)
        return nil unless destination

        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(source_path, destination)
        key
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

      def delete(key)
        path = resolve(key)
        return false unless path
        return false unless File.exist?(path)

        FileUtils.rm_f(path)
        true
      end

      def resolve(key)
        return nil if key.nil? || key.empty?

        expanded = File.expand_path(key, @folder_path)
        project_root = File.realpath(@folder_path)
        candidate = canonical_candidate(expanded)
        return nil unless candidate.start_with?("#{project_root}#{File::SEPARATOR}")

        candidate
      rescue Errno::ENOENT, Errno::EACCES
        nil
      end

      def exist?(key)
        path = resolve(key)
        path && File.exist?(path)
      end

      def relative_path(path)
        return path if path.nil? || path.empty?
        return path unless File.absolute_path(path).eql?(path)

        path.delete_prefix("#{@folder_path}#{File::SEPARATOR}")
      end

      def url(_key)
        nil
      end

      private

      def canonical_candidate(expanded)
        return File.realpath(expanded) if File.exist?(expanded)

        parent = File.dirname(expanded)
        canonical_parent = File.exist?(parent) ? File.realpath(parent) : File.expand_path(parent)
        File.join(canonical_parent, File.basename(expanded))
      end
    end
  end
end
