# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Exports
        def self.registered(app)
          app.post '/api/export' do
            body = json_body
            group_name = body['group']
            output_basename = body['output_basename']&.to_s&.strip
            halt 400, json_response(error: 'No group specified') if group_name.nil? || group_name.empty?

            begin
              spliced, kdenlive = project_exporter.export_group(group_name, output_basename)
              json_response(success: true, spliced: spliced, kdenlive: kdenlive)
            rescue StandardError => e
              mapped_error_response(e)
            end
          end
        end
      end
    end
  end
end
