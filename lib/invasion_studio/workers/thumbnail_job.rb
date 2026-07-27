# frozen_string_literal: true

require 'sucker_punch'

module InvasionStudio
  module Workers
    class ThumbnailJob
      include SuckerPunch::Job

      def perform(clip_id, folder_path)
        project = InvasionStudio::Project.new(folder_path)
        InvasionStudio::ThumbnailGenerator.new(project).generate(clip_id)
      rescue StandardError => e
        warn "ThumbnailJob failed for #{clip_id}: #{e.message}"
      end
    end
  end
end
