# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'uri'

module InvasionStudio
  module Webui
    class Server < Sinatra::Base
      set :views, File.expand_path('views', __dir__)
      set :public_folder, File.expand_path('public', __dir__)
      set :static, true
      set :host_authorization, { permitted_hosts: ['localhost', '127.0.0.1', '::1', 'example.org'] }
      set :json_request, JsonRequest.new
      set :error_mapper, ErrorMapper.new
      set :quiet, false
      set :file_opener, nil
      set :preview_remuxer, nil
      # nil = default cache locations; tests inject temp dirs so clearing the
      # cache never touches the real user cache.
      set :cache_dirs, nil

      before do
        headers 'X-Content-Type-Options' => 'nosniff',
                'Referrer-Policy' => 'no-referrer',
                'Content-Security-Policy' => "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; media-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"

        next unless %w[POST PUT PATCH DELETE].include?(request.request_method)
        origin = request.env['HTTP_ORIGIN']
        next if origin.nil? || origin.empty?

        expected = "#{request.scheme}://#{request.host_with_port}"
        halt 403, json_response(error: 'Cross-origin request rejected') unless origin == expected
      end

      def self.run!(folder_path, port: 4567, quiet: false)
        preview_cache = File.join(folder_path, '.preview_cache')
        FileUtils.rm_rf(preview_cache) if File.directory?(preview_cache)

        set :folder_path, folder_path
        project = InvasionStudio::Project.new(folder_path)
        set :project, project
        set :quiet, quiet
        set :file_opener, FileOpener.new
        set :preview_remuxer, PreviewRemuxer.new(folder_path)

        project.enqueue_missing_thumbnails
        project.enqueue_missing_metadata

        puts "Starting WebUI on http://localhost:#{port}"
        puts "Folder: #{folder_path}"
        puts "Press Ctrl+C to stop"
        puts

        super(port: port, bind: '127.0.0.1')
      end

      helpers do
        def project
          settings.project
        end

        def json_response(data)
          content_type :json
          JSON.generate(data)
        end

        def json_body
          settings.json_request.parse(request.body)
        rescue InvalidJsonRequest => e
          mapped_error_response(e, halt_response: true)
        end

        def mapped_error_response(error, halt_response: false)
          status_code, payload = settings.error_mapper.map(error)
          response = json_response(payload)
          halt status_code, response if halt_response
          status status_code
          response
        end

        def mutation_response(success, failure:)
          if success
            json_response(success: true)
          else
            status 400
            json_response(error: failure)
          end
        end

        def find_clip!(clip_id)
          clip = project.all_clips.find { |item| item['id'] == clip_id }
          halt 404, json_response(error: 'Clip not found') unless clip
          clip
        end

        def file_opener
          settings.file_opener || FileOpener.new
        end

        def preview_remuxer
          settings.preview_remuxer || PreviewRemuxer.new(settings.folder_path)
        end

        def group_statistics
          GroupStatistics.new(project)
        end

        def storage_statistics
          StorageStatistics.new(project, cache_dirs: settings.cache_dirs)
        end

        def game_statistics
          GameStatistics.new(project)
        end

        def project_exporter
          InvasionStudio::ProjectExporter.new(project, quiet: settings.quiet)
        end

        def clip_stream_path(clip)
          if clip['deleted'] && clip['trash_path']
            File.expand_path(clip['trash_path'], settings.folder_path)
          else
            project.resolve_clip_path(clip)
          end
        end

        def clip_with_thumbnail_url(clip)
          clip.merge(
            'groups' => project.clip_groups(clip['id']),
            'tags' => project.clip_tags(clip['id']),
            'thumbnail_url' => thumbnail_url_for(clip)
          )
        end

        def thumbnail_url_for(clip)
          return nil unless clip['thumbnail_path']

          '/thumbnail/' + URI.encode_www_form_component(clip['id'])
        end
      end

      # Tags must register before Clips: the greedy clip routes
      # (e.g. delete %r{/api/clip/(.+)}) would otherwise match tag paths.
      register Routes::Tags
      register Routes::Clips
      register Routes::Groups
      register Routes::Uploads
      register Routes::Exports
      register Routes::Storage
      register Routes::GameStats
      register Routes::Settings
      register Routes::Pages
    end
  end
end
