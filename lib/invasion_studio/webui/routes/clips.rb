# frozen_string_literal: true

module InvasionStudio
  module Webui
    module Routes
      module Clips
        def self.registered(app)
          app.get '/api/clips' do
            group = params['group']
            list = if params['all'] == 'true'
                     project.all_clips
                   elsif params['deleted'] == 'true'
                     project.deleted_clips
                   elsif group && !group.empty?
                     project.group_clips(group)
                   else
                     project.clips
                   end
            json_response(list.map { |clip| clip.merge('groups' => project.clip_groups(clip['id'])) })
          end

          app.post %r{/api/clip/(.+)/open} do
            clip_id = params['captures'][0]
            clip = find_clip!(clip_id)
            path = project.resolve_clip_path(clip)
            halt 400, json_response(error: 'File not found') unless path && File.exist?(path)

            file_opener.open(path)
            json_response(success: true, path: path)
          end

          app.post %r{/api/clip/(.+)/reveal} do
            clip_id = params['captures'][0]
            clip = find_clip!(clip_id)
            path = project.resolve_clip_path(clip)
            halt 400, json_response(error: 'File not found') unless path && File.exist?(path)

            file_opener.reveal(path)
            json_response(success: true, path: path)
          end

          app.post %r{/api/clip/(.+)/finalize} do
            clip_id = params['captures'][0]
            find_clip!(clip_id)
            if project.finalize_cuts(clip_id)
              json_response(success: true)
            else
              status 422
              json_response(error: 'Failed to finalize cuts')
            end
          end

          app.delete %r{/api/clip/(.+)} do
            clip_id = params['captures'][0]
            clip = find_clip!(clip_id)
            clip['deleted'] ? project.restore_clip(clip_id) : project.delete_clip(clip_id)
            json_response(success: true)
          end

          app.get %r{/api/clip/(.+)} do
            clip_id = params['captures'][0]
            json_response(find_clip!(clip_id))
          end

          app.post '/api/reorder' do
            body = json_body
            success = project.reorder_group(body['group'], body['old_index'].to_i, body['new_index'].to_i)
            mutation_response(success, failure: 'Failed to reorder')
          end

          {
            '/api/note' => [:update_note, 'note', ->(value) { value.to_s }, 'Failed to update note'],
            '/api/rating' => [:update_rating, 'rating', ->(value) { value.to_i }, 'Failed to update rating'],
            '/api/result' => [:update_result, 'result', ->(value) { value.to_s }, 'Failed to update result'],
            '/api/title' => [:update_title, 'title', ->(value) { value.to_s }, 'Failed to update title'],
            '/api/cuts' => [:update_cuts, 'cuts', ->(value) { value }, 'Failed to update cuts']
          }.each do |path, (method_name, field, coercion, failure)|
            app.post path do
              body = json_body
              success = project.public_send(method_name, body['id'], coercion.call(body[field]))
              mutation_response(success, failure: failure)
            end
          end

          app.get '/clip/:filename' do
            clip = project.all_clips.find { |item| item['filename'] == params['filename'] }
            halt 404 unless clip
            path = clip_stream_path(clip)
            halt 404 unless path && File.exist?(path)

            track = params['audio_track']
            if track&.match?(/^\d+$/)
              preview = preview_remuxer.remux(path, track.to_i)
              return send_file(preview, type: 'video/mp4', disposition: 'inline') if preview && File.exist?(preview)
            end
            send_file(path, type: 'video/mp4', disposition: 'inline')
          end
        end
      end
    end
  end
end
