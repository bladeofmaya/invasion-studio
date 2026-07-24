require 'test_helper'
require 'rack/test'
require 'fileutils'
require 'json'

class TestWebuiServer < Minitest::Test
  include Rack::Test::Methods

  def app
    InvasionStudio::Webui::Server
  end

  def setup
    @folder = Dir.mktmpdir
    File.write(File.join(@folder, 'project.json'), JSON.generate({
      'project' => 'test',
      'created_at' => Time.now.iso8601,
      'updated_at' => Time.now.iso8601,
      'clips' => [
        { 'id' => 'clip1', 'filename' => 'clip1.mp4', 'path' => 'clip1.mp4', 'title' => nil, 'note' => '', 'rating' => 0, 'result' => nil, 'cuts' => [], 'deleted' => false },
        { 'id' => 'clip2', 'filename' => 'clip2.mp4', 'path' => 'clip2.mp4', 'title' => 'Test', 'note' => 'Note', 'rating' => 3, 'result' => 'win', 'cuts' => [], 'deleted' => false }
      ],
      'groups' => [
        { 'name' => 'Group1', 'clip_ids' => ['clip1'] }
      ]
    }))
    File.write(File.join(@folder, 'clip1.mp4'), 'dummy')
    File.write(File.join(@folder, 'clip2.mp4'), 'dummy')
    InvasionStudio::Webui::Server.set :folder_path, @folder
    InvasionStudio::Webui::Server.set :project, InvasionStudio::Project.new(@folder)
  end

  def teardown
    FileUtils.rm_rf(@folder) if @folder
  end

  # ========== Page Routes ==========

  def test_get_root_returns_html
    get '/'
    assert last_response.ok?
    assert last_response.body.include?('Invasion Studio')
    assert last_response.body.include?('data-controller="clip-list"')
    assert last_response.body.include?('data-controller="video-player"')
    assert last_response.body.include?('data-controller="editor"')
    assert last_response.body.include?('data-controller="router navigation"')
  end

  def test_get_root_uses_only_local_executable_assets
    get '/'

    executable_assets = last_response.body.scan(
      /<(?:script|link)\b[^>]*(?:src|href)=["']([^"']+)["']/i
    ).flatten

    refute_empty executable_assets
    assert executable_assets.all? { |url| url.start_with?('/') }, executable_assets.inspect
    refute_match(/https?:\/\//i, last_response.body)
    refute_match(/type=["']importmap["']/i, last_response.body)
  end

  def test_get_compiled_stylesheet
    get '/assets/app.css'

    assert last_response.ok?
    assert_includes last_response.content_type, 'text/css'
    refute_empty last_response.body
  end

  def test_get_bundled_javascript
    get '/assets/app.js'

    assert last_response.ok?
    assert_includes last_response.content_type, 'javascript'
    refute_empty last_response.body
  end

  # ========== SPA Deep-Link Routes ==========

  def test_get_clips_deep_link_returns_shell
    get '/clips/clip1'
    assert last_response.ok?
    assert last_response.body.include?('Invasion Studio')
    assert last_response.body.include?('data-controller="router navigation"')
  end

  def test_get_groups_deep_link_returns_shell
    get '/groups'
    assert last_response.ok?
    assert last_response.body.include?('Invasion Studio')
  end

  def test_get_group_detail_deep_link_returns_shell
    get '/groups/Group1'
    assert last_response.ok?
    assert last_response.body.include?('Invasion Studio')
  end

  def test_get_group_detail_deep_link_with_encoded_name_returns_shell
    get '/groups/My%20Group%2FSub'
    assert last_response.ok?
    assert last_response.body.include?('Invasion Studio')
  end

  def test_get_group_clip_deep_link_returns_shell
    get '/groups/Group1/clips/clip1'
    assert last_response.ok?
    assert last_response.body.include?('Invasion Studio')
  end

  def test_deep_link_catch_all_does_not_shadow_api_clips
    get '/api/clips?all=true'
    assert last_response.ok?
    assert last_response.content_type.include?('application/json')
  end

  def test_deep_link_catch_all_does_not_shadow_api_groups
    get '/api/groups'
    assert last_response.ok?
    assert last_response.content_type.include?('application/json')
  end

  def test_deep_link_catch_all_does_not_shadow_clip_stream
    get '/clip/clip1.mp4'
    assert last_response.ok?
    refute last_response.body.include?('Invasion Studio')
  end

  # ========== API Routes ==========

  def test_get_api_clips_returns_json
    get '/api/clips?all=true'
    assert last_response.ok?
    assert last_response.content_type.include?('application/json')
    data = JSON.parse(last_response.body)
    assert_equal 2, data.length
    assert data.any? { |c| c['id'] == 'clip1' }
  end

  def test_get_api_clips_with_group_filter
    get '/api/clips?group=Group1'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 1, data.length
    assert_equal 'clip1', data[0]['id']
  end

  def test_get_api_clip_returns_single_clip
    get '/api/clip/clip1'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 'clip1', data['id']
  end

  def test_get_api_clip_not_found
    get '/api/clip/nonexistent'
    assert_equal 404, last_response.status
  end

  def test_post_api_title_updates_title
    post '/api/title', JSON.generate({ id: 'clip1', title: 'New Title' }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  end

  def test_post_api_note_updates_note
    post '/api/note', JSON.generate({ id: 'clip1', note: 'Updated note' }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  end

  def test_post_api_rating_updates_rating
    post '/api/rating', JSON.generate({ id: 'clip1', rating: 5 }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  end

  def test_post_api_result_updates_result
    post '/api/result', JSON.generate({ id: 'clip1', result: 'loss' }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  end

  def test_post_api_cuts_updates_cuts
    post '/api/cuts', JSON.generate({ id: 'clip1', cuts: [{ 'start' => 1.0, 'end' => 2.0 }] }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  end

  def test_delete_api_clip_deletes_clip
    delete '/api/clip/clip1'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
    # Verify clip is deleted
    get '/api/clip/clip1'
    clip = JSON.parse(last_response.body)
    assert_equal true, clip['deleted']
  end

  def test_delete_api_clip_restores_clip
    delete '/api/clip/clip1'
    delete '/api/clip/clip1'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
    # Verify clip is restored
    get '/api/clip/clip1'
    clip = JSON.parse(last_response.body)
    assert_equal false, clip['deleted']
  end

  def test_post_api_reorder_reorders_clips
    post '/api/reorder', JSON.generate({ group: 'Group1', old_index: 0, new_index: 0 }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  end

  def test_get_api_groups_returns_groups
    get '/api/groups'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 1, data.length
    assert_equal 'Group1', data[0]['name']
  end

  def test_get_api_groups_stats_returns_stats
    get '/api/groups/stats'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 1, data.length
    assert_equal 'Group1', data[0]['name']
    assert_equal 1, data[0]['clip_count']
  end

  def test_post_api_groups_creates_group
    post '/api/groups', JSON.generate({ name: 'NewGroup' }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
    assert_equal 'NewGroup', data['name']
  end

  def test_post_api_groups_rename_renames_group
    post '/api/groups/rename', JSON.generate({ old_name: 'Group1', new_name: 'RenamedGroup' }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
    assert_equal 'RenamedGroup', data['new_name']
  end

  def test_delete_api_groups_deletes_group
    delete '/api/groups/Group1'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  end

  def test_post_api_group_add_adds_clip
    post '/api/group/Group1/add', JSON.generate({ clip_id: 'clip2' }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  end

  def test_post_api_group_remove_removes_clip
    post '/api/group/Group1/remove', JSON.generate({ clip_id: 'clip1' }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  end

  def test_post_api_export_requires_group
    post '/api/export', JSON.generate({ group: nil }), 'CONTENT_TYPE' => 'application/json'
    assert_equal 400, last_response.status
  end

  def test_post_api_finalize_cuts_success
    # Set up a clip with cuts
    project = InvasionStudio::Webui::Server.settings.project
    project.update_cuts('clip1', [{ 'start' => 1.0, 'end' => 2.0 }])

    # Mock finalize_cuts on the project instance to avoid ffmpeg
    orig_finalize = project.method(:finalize_cuts)
    project.define_singleton_method(:finalize_cuts) { |_clip_id| true }

    post '/api/clip/clip1/finalize', '', 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  ensure
    project.define_singleton_method(:finalize_cuts, orig_finalize) if orig_finalize
  end

  def test_post_api_finalize_cuts_not_found
    post '/api/clip/nonexistent/finalize', '', 'CONTENT_TYPE' => 'application/json'
    assert_equal 404, last_response.status
  end

  def test_post_api_finalize_cuts_no_cuts
    project = InvasionStudio::Webui::Server.settings.project
    project.update_cuts('clip1', [])

    post '/api/clip/clip1/finalize', '', 'CONTENT_TYPE' => 'application/json'
    assert_equal 422, last_response.status
    data = JSON.parse(last_response.body)
    assert_equal 'Failed to finalize cuts', data['error']
  end
end
