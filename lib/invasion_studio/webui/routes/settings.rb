# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Settings
        def self.registered(app)
          app.get '/api/settings/video' do
            json_response(project.video_settings)
          end

          app.put '/api/settings/video' do
            body = json_body
            saved = project.update_video_settings(
              audio_track_count: body['audio_track_count'],
              default_audio_track: body['default_audio_track']
            )
            unless saved
              status 422
              next json_response(error: 'Invalid video settings')
            end

            json_response(project.video_settings)
          end
        end
      end
    end
  end
end
