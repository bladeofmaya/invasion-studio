# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Settings
        def self.registered(app)
          app.get '/api/settings/extraction' do
            json_response(ExtractionRequest.validate_options(project.extraction_settings))
          end

          app.put '/api/settings/extraction' do
            begin
              options = ExtractionRequest.validate_options(json_body)
              project.update_extraction_settings(options)
              json_response(options)
            rescue InvasionStudio::Error => e
              halt 422, json_response(error: e.message)
            end
          end

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
