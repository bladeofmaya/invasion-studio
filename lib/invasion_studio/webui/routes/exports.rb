# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Exports
        def self.registered(app)
          app.get '/api/export/status' do
            group_name = params['group'].to_s
            halt 400, json_response(error: 'No group specified') if group_name.empty?

            json_response(exists: project_exporter.export_exists?(group_name))
          end

          app.post '/api/export/reveal' do
            group_name = json_body['group'].to_s
            halt 400, json_response(error: 'No group specified') if group_name.empty?

            directory = project_exporter.export_directory(group_name)
            halt 404, json_response(error: 'Export not found') unless project_exporter.export_exists?(group_name)

            file_opener.open(directory)
            json_response(success: true, path: directory)
          end

          app.post '/api/export' do
            body = json_body
            group_name = body['group']
            overwrite = body['overwrite'] == true
            halt 400, json_response(error: 'No group specified') if group_name.nil? || group_name.empty?

            begin
              spliced, kdenlive = project_exporter.export_group(group_name, overwrite: overwrite)
              json_response(success: true, spliced: spliced, kdenlive: kdenlive)
            rescue ProjectExporter::ExportExists => e
              halt 409, json_response(error: e.message, overwrite_required: true)
            rescue StandardError => e
              mapped_error_response(e)
            end
          end
        end
      end
    end
  end
end
