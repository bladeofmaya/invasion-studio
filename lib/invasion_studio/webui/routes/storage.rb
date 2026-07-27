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
            freed = storage_statistics.clear_cache!
            json_response(success: true, freed_bytes: freed)
          end
        end
      end
    end
  end
end
