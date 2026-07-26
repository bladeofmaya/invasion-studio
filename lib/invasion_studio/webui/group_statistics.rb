# frozen_string_literal: true

module InvasionStudio
  module Webui
    class GroupStatistics
      def initialize(project, metadata_probe: ->(path) { Video.new(path).metadata })
        @project = project
        @metadata_probe = metadata_probe
      end

      def call
        @project.groups.map do |group|
          clips = @project.group_clips(group['name'])
          {
            'name' => group['name'],
            'clip_count' => clips.length,
            'total_duration' => total_duration(clips).round(2)
          }
        end
      end

      private

      def total_duration(clips)
        clips.sum do |clip|
          path = @project.resolve_clip_path(clip)
          next 0 unless path && File.exist?(path)

          metadata = @metadata_probe.call(path)
          metadata && metadata[:duration] ? @project.effective_duration(clip, metadata[:duration]) : 0
        end
      end
    end
  end
end
