# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Storage
        def self.registered(app)
          app.get '/api/storage/stats' do
            json_response(storage_statistics.call)
          end

          app.post '/api/storage/clear-cache' do
            body = json_body
            begin
              freed = storage_statistics.clear_cache!(scope: body.is_a?(Hash) ? body['scope'] : nil)
              json_response(success: true, freed_bytes: freed)
            rescue InvasionStudio::Error => e
              halt 422, json_response(error: e.message)
            end
          end
        end
      end
    end
  end
end
