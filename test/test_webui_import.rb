require 'test_helper'
require 'rack/test'

class TestWebuiImport < Minitest::Test
  include Rack::Test::Methods

  def app = InvasionStudio::Webui::Server

  def setup
    @folder = Dir.mktmpdir
    @project = InvasionStudio::Project.new(@folder)
    @jobs = []
    @task = InvasionStudio::Webui::ExtractionTask.new(@project, executor: ->(&job) { @jobs << job })
    app.set :project, @project
    app.set :folder_path, @folder
    app.set :extraction_task, @task
    @recording = File.join(@folder, 'long video.mp4')
    File.write(@recording, 'dummy')
  end

  def teardown
    app.set :extraction_task, nil
    FileUtils.rm_rf(@folder)
  end

  def test_import_deep_link_and_upload_controls_belong_to_import_panel
    get '/import'
    assert last_response.ok?
    assert_includes last_response.body, 'data-view="import"'
    assert_includes last_response.body, 'data-controller="extraction"'
    clip_panel = File.read(File.expand_path('../lib/invasion_studio/webui/views/_clip_panel.erb', __dir__))
    refute_includes clip_panel, 'upload#trigger'
    assert_includes last_response.body, 'upload#trigger'
  end

  def test_start_and_poll_extraction_without_processing_video
    get '/api/extraction'
    assert_equal 'idle', JSON.parse(last_response.body)['status']
    post '/api/extraction', JSON.generate(paths: [@recording], options: { ffmpeg_threads: 8, hwaccel: true }),
         'CONTENT_TYPE' => 'application/json'
    assert_equal 202, last_response.status
    id = JSON.parse(last_response.body)['id']
    get '/api/extraction'
    assert_equal id, JSON.parse(last_response.body)['id']
    assert_equal 'running', JSON.parse(last_response.body)['status']
    assert_equal 1, @jobs.length
    post '/api/extraction', JSON.generate(paths: [@recording]), 'CONTENT_TYPE' => 'application/json'
    assert_equal 409, last_response.status
  end

  def test_rejects_invalid_input_and_cross_origin_requests
    post '/api/extraction', JSON.generate(paths: ['/missing.mp4']), 'CONTENT_TYPE' => 'application/json'
    assert_equal 422, last_response.status
    post '/api/extraction', '[]', 'CONTENT_TYPE' => 'application/json'
    assert_equal 422, last_response.status
    post '/api/extraction', '{', 'CONTENT_TYPE' => 'application/json'
    assert_equal 400, last_response.status
    post '/api/extraction', JSON.generate(paths: [@recording]),
         'CONTENT_TYPE' => 'application/json', 'HTTP_ORIGIN' => 'https://untrusted.example'
    assert_equal 403, last_response.status
    assert_empty @jobs
  end
end
