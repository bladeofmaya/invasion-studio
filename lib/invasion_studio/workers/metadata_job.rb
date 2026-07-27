# frozen_string_literal: true

require 'sucker_punch'

module InvasionStudio
  module Workers
    class MetadataJob
      include SuckerPunch::Job

      def perform(clip_id, folder_path)
        project = InvasionStudio::Project.new(folder_path)
        InvasionStudio::ClipMetadataUpdater.new(project).update(clip_id)
      rescue StandardError => e
        warn "MetadataJob failed for #{clip_id}: #{e.message}"
      end
    end
  end
end
