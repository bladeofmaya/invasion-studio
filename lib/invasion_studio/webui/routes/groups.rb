# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Groups
        def self.registered(app)
          app.get('/api/groups') { json_response(project.groups) }
          app.get('/api/groups/stats') { json_response(group_statistics.call) }

          app.post '/api/groups' do
            name = json_body['name'].to_s.strip
            if name.empty?
              status 400
              return json_response(error: 'Group name cannot be empty')
            end
            unless CompilationName.valid?(name)
              status 422
              return json_response(error: 'Use a portable compilation name without / \\ : * ? " < > | or trailing dots')
            end
            if project.create_group(name)
              json_response(success: true, name: name)
            else
              status 409
              json_response(error: 'Group already exists')
            end
          end

          app.post '/api/groups/rename' do
            body = json_body
            old_name = body['old_name'].to_s.strip
            new_name = body['new_name'].to_s.strip
            if old_name.empty? || new_name.empty?
              status 400
              return json_response(error: 'Group names cannot be empty')
            end
            unless CompilationName.valid?(new_name)
              status 422
              return json_response(error: 'Use a portable compilation name without / \\ : * ? " < > | or trailing dots')
            end
            if project.rename_group(old_name, new_name)
              json_response(success: true, new_name: new_name)
            else
              status 409
              json_response(error: 'Group name already exists or not found')
            end
          end

          app.delete '/api/groups/:name' do
            if project.delete_group(params['name'])
              json_response(success: true)
            else
              halt 404, json_response(error: 'Group not found')
            end
          end

          app.post '/api/group/:name/add' do
            success = project.add_clip_to_group(params['name'], json_body['clip_id'])
            mutation_response(success, failure: 'Failed to add clip to group')
          end

          app.post '/api/group/:name/remove' do
            success = project.remove_clip_from_group(params['name'], json_body['clip_id'])
            mutation_response(success, failure: 'Failed to remove clip from group')
          end

          app.post '/api/group/:name/move' do
            body = json_body
            success = project.move_clip_between_groups(
              params['name'], body['destination'].to_s, body['clip_id']
            )
            mutation_response(success, failure: 'Failed to move clip to compilation')
          end
        end
      end
    end
  end
end
