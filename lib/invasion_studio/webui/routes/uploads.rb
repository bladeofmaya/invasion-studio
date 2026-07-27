# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Uploads
        def self.registered(app)
          app.post '/api/upload' do
            importer = InvasionStudio::ClipImporter.new(project)
            files = params['files']
            files = [files] unless files.is_a?(Array)

            results = files.filter_map do |file|
              next unless file.is_a?(Hash) && file[:tempfile]

              importer.import_upload(tempfile: file[:tempfile], filename: file[:filename])
            end

            json_response(success: true, imported: results.length, clips: results.map { |clip| clip['id'] })
          rescue InvasionStudio::Error => e
            status 422
            json_response(error: e.message)
          end
        end
      end
    end
  end
end
