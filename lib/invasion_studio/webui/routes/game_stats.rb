# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module GameStats
        def self.registered(app)
          app.get '/api/game/stats' do
            json_response(game_statistics.call)
          end
        end
      end
    end
  end
end
