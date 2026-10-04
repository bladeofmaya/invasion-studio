# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Settings
        def self.registered(app)
          app.get '/api/settings/interface' do
            json_response(project.interface_settings)
          end

          app.put '/api/settings/interface' do
            halt 422, json_response(error: 'Invalid interface settings') unless project.update_interface_settings(json_body)
            json_response(project.interface_settings)
          end

          app.get '/api/settings/dependencies' do
            configuration = settings.dependency_settings || DependencySettings.new
            begin
              json_response(tools: configuration.diagnostics, settings_path: configuration.path)
            rescue InvasionStudio::Error => e
              halt 422, json_response(error: e.message)
            end
          end

          app.put '/api/settings/dependencies' do
            configuration = settings.dependency_settings || DependencySettings.new
            begin
              configuration.update(json_body)
              json_response(tools: configuration.diagnostics, settings_path: configuration.path)
            rescue InvasionStudio::Error => e
              halt 422, json_response(error: e.message)
            end
          end

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
