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

          app.get '/api/clip/:id' do
            json_response(find_clip!(params['id']))
          end

          app.post '/api/clip/:id/open' do
            clip = find_clip!(params['id'])
            path = project.resolve_clip_path(clip)
            halt 400, json_response(error: 'File not found') unless path && File.exist?(path)

            file_opener.open(path)
            json_response(success: true, path: path)
          end

          app.delete '/api/clip/:id' do
            clip = find_clip!(params['id'])
            clip['deleted'] ? project.restore_clip(params['id']) : project.delete_clip(params['id'])
            json_response(success: true)
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

          app.post '/api/clip/:id/finalize' do
            find_clip!(params['id'])
            if project.finalize_cuts(params['id'])
              json_response(success: true)
            else
              status 422
              json_response(error: 'Failed to finalize cuts')
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
