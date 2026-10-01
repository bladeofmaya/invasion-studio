# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Extraction
        def self.registered(app)
          app.get '/api/extraction' do
            json_response(settings.extraction_task.status)
          end

          app.post '/api/extraction' do
            body = json_body
            halt 422, json_response(error: 'Expected a JSON object') unless body.is_a?(Hash)
            begin
              result = settings.extraction_task.start(paths: body['paths'], options: body.fetch('options', {}),
                                                      allow_reimport: body.fetch('allow_reimport', false))
              status 202
              json_response(result)
            rescue ExtractionTask::Busy => e
              halt 409, json_response(error: e.message)
            rescue InvasionStudio::Error, ArgumentError => e
              halt 422, json_response(error: e.message)
            end
          end
        end
      end
    end
  end
end
