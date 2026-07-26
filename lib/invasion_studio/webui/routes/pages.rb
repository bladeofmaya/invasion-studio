# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Pages
        def self.registered(app)
          app.get('/') { erb :index }

          # Registered after API/media routes so SPA deep links cannot shadow them.
          app.get %r{/(clips|groups)(/.*)?} do
            erb :index
          end
        end
      end
    end
  end
end
