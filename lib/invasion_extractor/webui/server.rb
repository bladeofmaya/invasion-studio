require 'sinatra/base'
require 'json'

module InvasionExtractor
  module Webui
    class Server < Sinatra::Base
      set :views, File.expand_path('views', __dir__)
      set :public_folder, File.expand_path('public', __dir__)
      set :static, true
      set :host_authorization, { permitted_hosts: [] }

      def self.run!(folder_path, port: 4567, quiet: false)
        set :folder_path, folder_path
        set :project, InvasionExtractor::Project.new(folder_path)
        set :quiet, quiet

        puts "Starting WebUI on http://localhost:#{port}"
        puts "Folder: #{folder_path}"
        puts "Press Ctrl+C to stop"
        puts

        super(port: port, bind: '0.0.0.0')
      end

      helpers do
        def project
          settings.project
        end

        def json_response(data)
          content_type :json
          JSON.generate(data)
        end
      end

      get '/' do
        erb :index
      end

      get '/api/clips' do
        group = params['group']
        include_deleted = params['deleted'] == 'true'
        include_all = params['all'] == 'true'

        list = if include_all
                 project.all_clips
               elsif include_deleted
                 project.deleted_clips
               elsif group && !group.empty?
                 project.group_clips(group)
               else
                 project.clips
               end

        # Add group membership info to each clip
        list_with_groups = list.map do |clip|
          clip.merge('groups' => project.clip_groups(clip['id']))
        end

        json_response(list_with_groups)
      end

      get '/api/clip/:id' do
        clip = project.all_clips.find { |c| c['id'] == params['id'] }
        halt 404, json_response({ error: 'Clip not found' }) unless clip
        json_response(clip)
      end

      post '/api/clip/:id/open' do
        clip = project.all_clips.find { |c| c['id'] == params['id'] }
        halt 404, json_response({ error: 'Clip not found' }) unless clip

        full_path = project.resolve_clip_path(clip)
        halt 400, json_response({ error: 'File not found' }) unless full_path && File.exist?(full_path)

        if RbConfig::CONFIG['host_os'] =~ /darwin/
          system('open', full_path)
        else
          system('xdg-open', full_path)
        end

        json_response({ success: true, path: full_path })
      end

      delete '/api/clip/:id' do
        clip = project.all_clips.find { |c| c['id'] == params['id'] }
        halt 404, json_response({ error: 'Clip not found' }) unless clip

        if clip['deleted']
          project.restore_clip(params['id'])
        else
          project.delete_clip(params['id'])
        end

        json_response({ success: true })
      end

      post '/api/reorder' do
        body = JSON.parse(request.body.read)
        group_name = body['group']
        old_index = body['old_index'].to_i
        new_index = body['new_index'].to_i

        if project.reorder_group(group_name, old_index, new_index)
          json_response({ success: true })
        else
          status 400
          json_response({ error: 'Failed to reorder' })
        end
      end

      post '/api/note' do
        body = JSON.parse(request.body.read)
        id = body['id']
        note = body['note'].to_s

        if project.update_note(id, note)
          json_response({ success: true })
        else
          status 400
          json_response({ error: 'Failed to update note' })
        end
      end

      post '/api/rating' do
        body = JSON.parse(request.body.read)
        id = body['id']
        rating = body['rating'].to_i

        if project.update_rating(id, rating)
          json_response({ success: true })
        else
          status 400
          json_response({ error: 'Failed to update rating' })
        end
      end

      post '/api/result' do
        body = JSON.parse(request.body.read)
        id = body['id']
        result = body['result'].to_s

        if project.update_result(id, result)
          json_response({ success: true })
        else
          status 400
          json_response({ error: 'Failed to update result' })
        end
      end

      post '/api/title' do
        body = JSON.parse(request.body.read)
        id = body['id']
        title = body['title'].to_s

        if project.update_title(id, title)
          json_response({ success: true })
        else
          status 400
          json_response({ error: 'Failed to update title' })
        end
      end

      post '/api/cuts' do
        body = JSON.parse(request.body.read)
        id = body['id']
        cuts = body['cuts']

        if project.update_cuts(id, cuts)
          json_response({ success: true })
        else
          status 400
          json_response({ error: 'Failed to update cuts' })
        end
      end

      get '/api/groups' do
        json_response(project.groups)
      end

      get '/api/groups/stats' do
        stats = project.groups.map do |g|
          group_clips = project.group_clips(g['name'])
          total_duration = group_clips.sum do |c|
            resolved_path = project.resolve_clip_path(c)
            next 0 unless resolved_path && File.exist?(resolved_path)
            video = Video.new(resolved_path)
            meta = video.metadata
            meta && meta[:duration] ? meta[:duration] : 0
          end
          {
            'name' => g['name'],
            'clip_count' => group_clips.length,
            'total_duration' => total_duration.round(2)
          }
        end
        json_response(stats)
      end

      post '/api/groups' do
        body = JSON.parse(request.body.read)
        name = body['name'].to_s.strip

        if name.empty?
          status 400
          return json_response({ error: 'Group name cannot be empty' })
        end

        if project.create_group(name)
          json_response({ success: true, name: name })
        else
          status 409
          json_response({ error: 'Group already exists' })
        end
      end

      post '/api/groups/rename' do
        body = JSON.parse(request.body.read)
        old_name = body['old_name'].to_s.strip
        new_name = body['new_name'].to_s.strip

        if old_name.empty? || new_name.empty?
          status 400
          return json_response({ error: 'Group names cannot be empty' })
        end

        if project.rename_group(old_name, new_name)
          json_response({ success: true, new_name: new_name })
        else
          status 409
          json_response({ error: 'Group name already exists or not found' })
        end
      end

      delete '/api/groups/:name' do
        group_name = params['name']
        project.delete_group(group_name)
        json_response({ success: true })
      end

      post '/api/group/:name/add' do
        body = JSON.parse(request.body.read)
        clip_id = body['clip_id']

        if project.add_clip_to_group(params['name'], clip_id)
          json_response({ success: true })
        else
          status 400
          json_response({ error: 'Failed to add clip to group' })
        end
      end

      post '/api/group/:name/remove' do
        body = JSON.parse(request.body.read)
        clip_id = body['clip_id']

        if project.remove_clip_from_group(params['name'], clip_id)
          json_response({ success: true })
        else
          status 400
          json_response({ error: 'Failed to remove clip from group' })
        end
      end

      post '/api/export' do
        body = JSON.parse(request.body.read)
        group_name = body['group']
        output_basename = body['output_basename']&.to_s&.strip

        halt 400, json_response({ error: 'No group specified' }) if group_name.nil? || group_name.empty?

        begin
          exporter = InvasionExtractor::ProjectExporter.new(project, quiet: settings.quiet)
          spliced, kdenlive = exporter.export_group(group_name, output_basename)
          json_response({ success: true, spliced: spliced, kdenlive: kdenlive })
        rescue => e
          status 500
          json_response({ error: e.message })
        end
      end

      get '/clip/:filename' do
        path = File.join(settings.folder_path, params['filename'])
        unless File.exist?(path)
          path = File.join(settings.folder_path, '.trashed', params['filename'])
          halt 404 unless File.exist?(path)
        end

        audio_track = params['audio_track']
        if audio_track && audio_track.match?(/^\d+$/)
          preview_path = preview_with_audio_track(path, audio_track.to_i)
          return send_file(preview_path, type: 'video/mp4', disposition: 'inline')
        end

        send_file(path, type: 'video/mp4', disposition: 'inline')
      end

      private

      def preview_with_audio_track(original_path, track_number)
        preview_dir = File.join(settings.folder_path, '.preview_cache')
        FileUtils.mkdir_p(preview_dir)

        basename = File.basename(original_path, '.*')
        preview_path = File.join(preview_dir, "#{basename}_audio#{track_number}.mp4")

        return preview_path if File.exist?(preview_path)

        # ffmpeg uses 0-based audio track indexing, so track 4 is 0:a:3
        audio_index = track_number - 1
        cmd = [
          'ffmpeg', '-y',
          '-i', original_path,
          '-map', '0:v:0',
          '-map', "0:a:#{audio_index}",
          '-c', 'copy',
          preview_path
        ]

        system(*cmd)
        preview_path
      end
    end
  end
end
