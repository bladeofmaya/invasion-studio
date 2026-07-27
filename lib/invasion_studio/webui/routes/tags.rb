# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Tags
        def self.registered(app)
          app.get '/api/tags' do
            json_response(project.tags)
          end

          app.get '/api/tags/details' do
            json_response(project.tag_details)
          end

          app.post '/api/tags/rename' do
            body = json_body
            old_name = body['old_name'].to_s.strip
            new_name = body['new_name'].to_s.strip
            if old_name.empty? || new_name.empty?
              status 400
              return json_response(error: 'Tag names cannot be empty')
            end
            if project.rename_tag(old_name, new_name)
              json_response(success: true, new_name: new_name)
            else
              status 409
              json_response(error: 'Tag name already exists or not found')
            end
          end

          app.delete '/api/tags/:name' do
            if project.delete_tag(params['name'])
              json_response(success: true)
            else
              halt 404, json_response(error: 'Tag not found')
            end
          end

          app.post %r{/api/clip/(.+)/tags} do
            clip_id = params['captures'][0]
            find_clip!(clip_id)
            body = json_body
            if project.add_tag(clip_id, body['name'])
              json_response(success: true, tags: project.clip_tags(clip_id))
            else
              status 400
              json_response(error: 'Failed to add tag')
            end
          end

          app.delete %r{/api/clip/(.+)/tags/(.+)} do
            clip_id = params['captures'][0]
            name = URI.decode_www_form_component(params['captures'][1])
            find_clip!(clip_id)
            project.remove_tag(clip_id, name)
            json_response(success: true, tags: project.clip_tags(clip_id))
          end
        end
      end
    end
  end
end
