# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Tags
        def self.registered(app)
          app.get '/api/tags' do
            json_response(project.tags)
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
