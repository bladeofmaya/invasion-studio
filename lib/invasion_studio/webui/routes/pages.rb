# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Pages
        def self.registered(app)
          # Development-only polling works in both Electron and a normal browser.
          # A new process token also reloads browser tabs after backend restarts.
          if ENV['INVASION_STUDIO_DEV'] == '1' && ENV['APP_ENV'] == 'development'
            require 'digest'
            boot_token = "#{Process.pid}:#{Time.now.to_f}"
            app.get('/__dev/revision') do
              headers 'Cache-Control' => 'no-store'
              content_type :text
              files = Dir[File.join(settings.views, '**', '*'),
                          File.join(settings.public_folder, 'assets', '*')].select { |file| File.file?(file) }
              signature = files.sort.map { |file| "#{file}:#{File.mtime(file).to_f}:#{File.size(file)}" }
              Digest::SHA256.hexdigest(([boot_token] + signature).join("\n"))
            end
          end

          app.get('/') { erb :index }
          app.get('/import') { erb :index }

          # Registered after API/media routes so SPA deep links cannot shadow them.
          app.get %r{/(clips|groups)(/.*)?} do
            erb :index
          end
        end
      end
    end
  end
end
