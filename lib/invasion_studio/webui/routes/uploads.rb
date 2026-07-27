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

            imported = []
            errors = []
            files.each do |file|
              next unless file.is_a?(Hash) && file[:tempfile]

              begin
                imported << importer.import_upload(tempfile: file[:tempfile], filename: file[:filename])
              rescue InvasionStudio::Error => e
                errors << { filename: file[:filename], error: e.message }
              end
            end

            status 422 if imported.empty? && errors.any?
            payload = {
              success: errors.empty?,
              imported: imported.length,
              clips: imported.map { |clip| clip['id'] },
              errors: errors
            }
            payload[:error] = "#{errors.length} file(s) failed" if errors.any?
            json_response(payload)
          end
        end
      end
    end
  end
end
