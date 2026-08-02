require 'test_helper'
require 'rack/test'
require 'fileutils'
require 'json'
require 'open3'
require 'uri'

class TestWebuiServer < Minitest::Test
  include Rack::Test::Methods

  def app
    InvasionStudio::Webui::Server
  end

  def setup
    @folder = Dir.mktmpdir
    File.write(File.join(@folder, 'clip1.mp4'), 'dummy')
    File.write(File.join(@folder, 'clip2.mp4'), 'dummy')
    @project = InvasionStudio::Project.new(@folder)
    project.delete_group('Video 1')
    project.create_group('Group1')
    project.add_clip_to_group('Group1', 'clip1')
    project.update_title('clip2', 'Test')
    project.update_note('clip2', 'Note')
    project.update_rating('clip2', 3)
    project.update_result('clip2', 'win')
    InvasionStudio::Webui::Server.set :folder_path, @folder
    InvasionStudio::Webui::Server.set :project, project
    InvasionStudio::Webui::Server.set :file_opener, nil
    InvasionStudio::Webui::Server.set :preview_remuxer, nil
  end

  def teardown
    FileUtils.rm_rf(@folder) if @folder
  end

  def project
    @project
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

  def test_saved_cut_changes_update_the_finalize_button
    get '/'

    assert_includes last_response.body, 'video-player:cuts-saved@window->editor#updateFinalizeButton'

    controller = File.read(File.expand_path(
      '../lib/invasion_studio/webui/public/controllers/video_player_controller.js', __dir__
    ))
    assert_includes controller, "this.dispatch('cuts-saved'"
  end

  def test_finalized_cuts_reload_the_video
    get '/'

    assert_includes last_response.body, 'editor:cuts-finalized->video-player#reloadFinalizedClip'

    editor = File.read(File.expand_path(
      '../lib/invasion_studio/webui/public/controllers/editor_controller.js', __dir__
    ))
    assert_includes editor, "this.dispatch('cuts-finalized'"
  end

  def test_new_group_form_has_submit_and_cancel_actions
    get '/'

    assert_includes last_response.body, 'submit->group-manager#createGroup'
    assert_match(/<button[^>]+type="submit"[^>]*>Create compilation<\/button>/, last_response.body)
    assert_includes last_response.body, 'click->group-manager#cancelNewGroupForm'
  end

  def test_shell_includes_theme_switcher_result_select_and_reveal_action
    get '/'

    assert_includes last_response.body, 'data-controller="theme"'
    assert_includes last_response.body, 'click->theme#toggle'
    assert_includes last_response.body, '<select'
    assert_includes last_response.body, 'data-editor-target="resultSelect"'
    refute_includes last_response.body, 'type="radio"'
    assert_includes last_response.body, '>Result...</option>'
    assert_includes last_response.body, 'Reveal File'
    assert_includes last_response.body, 'data-lucide="folder-open"'

    controller = File.read(File.expand_path(
      '../lib/invasion_studio/webui/public/controllers/video_player_controller.js', __dir__
    ))
    assert_includes controller, "revealFile"
    assert_match(/\/api\/clip\/.*\+\s*['\"]\/reveal['\"]/, controller)
  end

  def test_lucide_is_a_bundled_dependency
    package = JSON.parse(File.read(File.expand_path('../package.json', __dir__)))

    assert_equal '1.27.0', package.dig('dependencies', 'lucide')
  end

  def test_sortablejs_is_a_bundled_dependency
    package = JSON.parse(File.read(File.expand_path('../package.json', __dir__)))

    assert_equal '1.15.7', package.dig('dependencies', 'sortablejs')
  end

  def test_sets_security_headers
    get '/'

    assert_equal 'nosniff', last_response.headers['X-Content-Type-Options']
    assert_includes last_response.headers['Content-Security-Policy'], "default-src 'self'"
  end

  def test_get_root_uses_only_local_executable_assets
    get '/'

    executable_assets = last_response.body.scan(
      /<(?:script|link|img|iframe)\b[^>]*(?:src|href)=["']([^"']+)["']/i
    ).flatten

    refute_empty executable_assets
    assert executable_assets.all? { |url| url.start_with?('/') }, executable_assets.inspect
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

  def test_get_api_clips_supports_search_params
    get '/api/clips?q=Test'
    assert_equal %w[clip2], JSON.parse(last_response.body).map { |c| c['id'] }

    get '/api/clips?filter=unassigned'
    assert_equal %w[clip2], JSON.parse(last_response.body).map { |c| c['id'] }

    get '/api/clips?filter=assigned'
    assert_equal %w[clip1], JSON.parse(last_response.body).map { |c| c['id'] }

    get '/api/clips?rating=3&result=win'
    assert_equal %w[clip2], JSON.parse(last_response.body).map { |c| c['id'] }

    get '/api/clips?sort=rating-desc'
    assert_equal %w[clip2 clip1], JSON.parse(last_response.body).map { |c| c['id'] }
  end

  def test_get_api_clips_supports_tag_param
    project.add_tag('clip1', 'parry')

    get '/api/clips?tag=parry'

    assert_equal %w[clip1], JSON.parse(last_response.body).map { |c| c['id'] }
  end

  def test_get_api_clips_filter_deleted
    project.delete_clip('clip1')

    get '/api/clips?filter=deleted'

    assert_equal %w[clip1], JSON.parse(last_response.body).map { |c| c['id'] }
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
    assert_equal({ 'error' => 'Clip not found' }, JSON.parse(last_response.body))
  end

  def test_post_empty_trash_purges_deleted_clips
    project.delete_clip('clip1')

    post '/api/trash/empty'

    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
    assert_equal 1, data['purged']
    assert_nil project.find_clip('clip1')
    refute File.exist?(File.join(@folder, '.trashed', 'clip1.mp4'))
    assert File.exist?(File.join(@folder, 'clip2.mp4'))
  end

  def test_shell_labels_deleted_filter_as_trash_with_empty_trash_button
    get '/'

    assert_includes last_response.body, '<option value="deleted">Trash</option>'
    assert_includes last_response.body, 'data-clip-list-target="emptyTrashBtn"'
    assert_includes last_response.body, 'click->clip-list#emptyTrash'
  end

  def test_shell_header_has_clip_count_bubble
    get '/'

    assert_includes last_response.body, 'data-clip-list-target="clipCount"'
  end

  def test_shell_includes_upload_progress_overlay
    get '/'

    assert_includes last_response.body, 'data-upload-target="overlay"'
    assert_includes last_response.body, 'data-upload-target="progressBar"'
    assert_includes last_response.body, 'data-upload-target="progressStatus"'
    assert_includes last_response.body, 'data-upload-target="closeBtn"'
    assert_includes last_response.body, 'click->upload#closeOverlay'
  end

  def test_uploader_splits_large_selections_into_size_bounded_requests
    controller = File.read(File.expand_path(
      '../lib/invasion_studio/webui/public/controllers/upload_controller.js', __dir__
    ))

    assert_includes controller, 'partitionUploadBatches'
    assert_includes controller, 'uploadBatches(files)'
    assert_includes controller, 'for (const batch of batches)'

    batches = upload_batch_sizes([3, 3, 3, 1].map { |gib| gib * 1024**3 })
    assert_equal [[3, 3], [3, 1]], batches.map { |batch| batch.map { |bytes| bytes / 1024**3 } }
    assert_equal 25, upload_progress_percent(
      uploaded_bytes: 0, loaded: 2 * 1024**3, total: 0,
      batch_bytes: 8 * 1024**3, total_bytes: 8 * 1024**3
    )
  end

  def test_shell_includes_search_controls
    get '/'

    assert_includes last_response.body, 'data-clip-list-target="searchControls"'
    assert_includes last_response.body, 'data-clip-list-target="searchInput"'
    assert_includes last_response.body, 'data-clip-list-target="tagFilter"'
    assert_includes last_response.body, 'data-clip-list-target="ratingFilter"'
    assert_includes last_response.body, 'data-clip-list-target="resultFilter"'
    assert_includes last_response.body, 'input->clip-list#setSearch'
    assert_includes last_response.body, '<option value="__none__">Untagged</option>'
    assert_includes last_response.body, '<option value="__none__">Unrated</option>'
    assert_includes last_response.body, '<option value="__none__">No result</option>'
  end

  def test_api_clips_filters_for_missing_tag_rating_and_result
    project.add_tag('clip2', 'parry')

    get '/api/clips?tag=__none__'
    assert_equal %w[clip1], JSON.parse(last_response.body).map { |clip| clip['id'] }

    get '/api/clips?rating=__none__'
    assert_equal %w[clip1], JSON.parse(last_response.body).map { |clip| clip['id'] }

    get '/api/clips?result=__none__'
    assert_equal %w[clip1], JSON.parse(last_response.body).map { |clip| clip['id'] }
  end

  def test_shell_includes_tag_editor
    get '/'

    assert_includes last_response.body, 'data-editor-target="tagList"'
    assert_includes last_response.body, 'data-editor-target="tagInput"'
    assert_includes last_response.body, 'data-editor-target="tagSuggestions"'
    assert_includes last_response.body, 'keydown->editor#tagKeydown'
    assert_includes last_response.body, 'mousedown->editor#pickTagSuggestion'
    assert_includes last_response.body, 'click->editor#removeTag'
  end

  # ========== Tag Routes ==========

  def test_get_api_tags_returns_sorted_names
    project.add_tag('clip1', 'Parry')
    project.add_tag('clip2', 'ambush')

    get '/api/tags'

    assert last_response.ok?
    assert_equal %w[ambush parry], JSON.parse(last_response.body)
  end

  def test_get_api_tag_details_returns_counts
    project.add_tag('clip1', 'parry')
    project.add_tag('clip2', 'parry')
    project.add_tag('clip1', 'ambush')

    get '/api/tags/details'

    assert last_response.ok?
    assert_equal(
      [
        { 'name' => 'ambush', 'clip_count' => 1 },
        { 'name' => 'parry', 'clip_count' => 2 }
      ],
      JSON.parse(last_response.body)
    )
  end

  def test_post_api_tags_rename
    project.add_tag('clip1', 'parry')

    post '/api/tags/rename', JSON.generate({ old_name: 'parry', new_name: 'riposte' }),
         'CONTENT_TYPE' => 'application/json'

    assert last_response.ok?
    assert_equal %w[riposte], project.tags
    assert_equal %w[riposte], project.clip_tags('clip1')
  end

  def test_post_api_tags_rename_conflict_and_blank
    project.add_tag('clip1', 'parry')
    project.add_tag('clip1', 'ambush')

    post '/api/tags/rename', JSON.generate({ old_name: 'parry', new_name: 'ambush' }),
         'CONTENT_TYPE' => 'application/json'
    assert_equal 409, last_response.status

    post '/api/tags/rename', JSON.generate({ old_name: 'parry', new_name: '  ' }),
         'CONTENT_TYPE' => 'application/json'
    assert_equal 400, last_response.status
  end

  def test_delete_api_tag_removes_tag_everywhere
    project.add_tag('clip1', 'parry')
    project.add_tag('clip2', 'parry')

    delete '/api/tags/parry'

    assert last_response.ok?
    assert_empty project.tags
    assert_empty project.clip_tags('clip1')

    delete '/api/tags/parry'
    assert_equal 404, last_response.status
  end

  def test_shell_includes_settings_dialog
    get '/'

    assert_includes last_response.body, 'click->settings#open'
    assert_includes last_response.body, 'data-settings-target="tagList"'
    assert_includes last_response.body, 'data-category="tags"'
    assert_includes last_response.body, 'data-category="storage"'
    assert_includes last_response.body, 'data-settings-target="storagePanel"'
  end

  # ========== Storage Routes ==========

  def test_get_api_storage_stats
    cache_dir = Dir.mktmpdir
    File.write(File.join(cache_dir, 'cached.yml'), 'x' * 25)
    InvasionStudio::Webui::Server.set :cache_dirs, [cache_dir]

    get '/api/storage/stats'

    assert last_response.ok?
    stats = JSON.parse(last_response.body)
    assert_equal 2, stats['clips']['count']
    assert_equal 25, stats['cache']['bytes']
    assert stats['total_bytes'].positive?
  ensure
    InvasionStudio::Webui::Server.set :cache_dirs, nil
    FileUtils.rm_rf(cache_dir)
  end

  def test_post_api_storage_clear_cache
    cache_dir = Dir.mktmpdir
    File.write(File.join(cache_dir, 'cached.yml'), 'x' * 25)
    InvasionStudio::Webui::Server.set :cache_dirs, [cache_dir]

    post '/api/storage/clear-cache'

    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 25, data['freed_bytes']
    assert_empty Dir.children(cache_dir)
  ensure
    InvasionStudio::Webui::Server.set :cache_dirs, nil
    FileUtils.rm_rf(cache_dir)
  end

  def test_post_clip_tag_adds_tag_and_returns_tags
    post '/api/clip/clip1/tags', JSON.generate({ name: 'Parry' }), 'CONTENT_TYPE' => 'application/json'

    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
    assert_equal ['parry'], data['tags']
    assert_equal ['parry'], project.clip_tags('clip1')
  end

  def test_post_clip_tag_rejects_blank_name
    post '/api/clip/clip1/tags', JSON.generate({ name: '   ' }), 'CONTENT_TYPE' => 'application/json'

    assert_equal 400, last_response.status
    assert_equal 'Failed to add tag', JSON.parse(last_response.body)['error']
  end

  def test_post_clip_tag_clip_not_found
    post '/api/clip/nonexistent/tags', JSON.generate({ name: 'parry' }), 'CONTENT_TYPE' => 'application/json'

    assert_equal 404, last_response.status
    assert_equal({ 'error' => 'Clip not found' }, JSON.parse(last_response.body))
  end

  def test_delete_clip_tag_removes_tag
    project.add_tag('clip1', 'parry')

    delete '/api/clip/clip1/tags/parry'

    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
    assert_equal [], data['tags']
    assert_equal [], project.clip_tags('clip1')
  end

  def test_delete_clip_tag_with_encoded_name
    project.add_tag('clip1', 'no estus')

    delete '/api/clip/clip1/tags/' + URI.encode_www_form_component('no estus')

    assert last_response.ok?
    assert_equal [], project.clip_tags('clip1')
  end

  def test_delete_clip_still_works_with_tag_routes_registered
    delete '/api/clip/clip1'

    assert last_response.ok?
    assert_equal true, JSON.parse(last_response.body)['success']
    assert project.find_clip('clip1')['deleted']
  end

  def test_api_clips_include_tags
    project.add_tag('clip1', 'parry')

    get '/api/clips?all=true'
    clip = JSON.parse(last_response.body).find { |c| c['id'] == 'clip1' }
    assert_equal ['parry'], clip['tags']

    get '/api/clip/clip1'
    assert_equal ['parry'], JSON.parse(last_response.body)['tags']
  end

  def test_open_clip_not_found_contract
    post '/api/clip/nonexistent/open'

    assert_equal 404, last_response.status
    assert_equal({ 'error' => 'Clip not found' }, JSON.parse(last_response.body))
  end

  def test_open_clip_uses_file_open_service
    opened_paths = []
    opener = Object.new
    opener.define_singleton_method(:open) { |path| opened_paths << path; true }
    InvasionStudio::Webui::Server.set :file_opener, opener

    post '/api/clip/clip1/open'

    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
    assert_equal [File.join(@folder, 'clip1.mp4')], opened_paths
  end

  def test_reveal_clip_uses_file_reveal_service
    revealed_paths = []
    opener = Object.new
    opener.define_singleton_method(:reveal) { |path| revealed_paths << path; true }
    InvasionStudio::Webui::Server.set :file_opener, opener

    post '/api/clip/clip1/reveal'

    assert last_response.ok?
    assert_equal [File.join(@folder, 'clip1.mp4')], revealed_paths
  end

  def test_clip_audio_preview_uses_remuxer_service
    preview = File.join(@folder, 'preview.mp4')
    File.write(preview, 'preview bytes')
    calls = []
    remuxer = Object.new
    remuxer.define_singleton_method(:remux) { |path, track| calls << [path, track]; preview }
    InvasionStudio::Webui::Server.set :preview_remuxer, remuxer

    get '/clip/clip1.mp4?audio_track=2'

    assert last_response.ok?
    assert_equal 'preview bytes', last_response.body
    assert_equal [[File.join(@folder, 'clip1.mp4'), 2]], calls
  end

  def test_post_api_title_updates_title
    post '/api/title', JSON.generate({ id: 'clip1', title: 'New Title' }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  end

  def test_rejects_invalid_json
    post '/api/title', '{', 'CONTENT_TYPE' => 'application/json'

    assert_equal 400, last_response.status
    assert_equal 'Invalid JSON request body', JSON.parse(last_response.body)['error']
  end

  def test_rejects_cross_origin_mutation
    post '/api/title', JSON.generate({ id: 'clip1', title: 'Nope' }), {
      'CONTENT_TYPE' => 'application/json',
      'HTTP_ORIGIN' => 'https://attacker.example'
    }

    assert_equal 403, last_response.status
  end

  def test_post_api_note_updates_note
    post '/api/note', JSON.generate({ id: 'clip1', note: 'Updated note' }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  end

  def test_metadata_updates_reject_unknown_clip
    {
      '/api/title' => { id: 'missing', title: 'Title' },
      '/api/note' => { id: 'missing', note: 'Note' },
      '/api/rating' => { id: 'missing', rating: 3 },
      '/api/result' => { id: 'missing', result: 'win' },
      '/api/cuts' => { id: 'missing', cuts: [] }
    }.each do |path, payload|
      post path, JSON.generate(payload), 'CONTENT_TYPE' => 'application/json'

      assert_equal 400, last_response.status, path
      assert JSON.parse(last_response.body).key?('error'), path
    end
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

  def test_delete_unknown_clip_contract
    delete '/api/clip/missing'

    assert_equal 404, last_response.status
    assert_equal({ 'error' => 'Clip not found' }, JSON.parse(last_response.body))
  end

  def test_post_api_reorder_reorders_clips
    post '/api/reorder', JSON.generate({ group: 'Group1', old_index: 0, new_index: 0 }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
  end

  def test_post_api_reorder_rejects_invalid_indices
    post '/api/reorder', JSON.generate({ group: 'Group1', old_index: 0, new_index: 9 }), 'CONTENT_TYPE' => 'application/json'

    assert_equal 400, last_response.status
    assert_equal({ 'error' => 'Failed to reorder' }, JSON.parse(last_response.body))
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

  def test_get_api_groups_stats_subtracts_saved_cuts
    project = InvasionStudio::Webui::Server.settings.project
    project.update_cuts('clip1', [{ 'start' => 2.0, 'end' => 5.0 }])
    fake_video = Struct.new(:metadata).new({ duration: 10.0 })
    original_new = InvasionStudio::Video.method(:new)
    InvasionStudio::Video.define_singleton_method(:new) { |_path| fake_video }

    get '/api/groups/stats'

    stat = JSON.parse(last_response.body).find { |item| item['name'] == 'Group1' }
    assert_in_delta 7.0, stat['total_duration']
  ensure
    InvasionStudio::Video.define_singleton_method(:new, original_new) if original_new
  end

  def test_post_api_groups_creates_group
    post '/api/groups', JSON.generate({ name: 'NewGroup' }), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal true, data['success']
    assert_equal 'NewGroup', data['name']
  end

  def test_post_api_groups_rejects_empty_and_duplicate_names
    post '/api/groups', JSON.generate({ name: ' ' }), 'CONTENT_TYPE' => 'application/json'
    assert_equal 400, last_response.status

    post '/api/groups', JSON.generate({ name: 'Group1' }), 'CONTENT_TYPE' => 'application/json'
    assert_equal 409, last_response.status
    assert_equal({ 'error' => 'Group already exists' }, JSON.parse(last_response.body))
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

  def test_delete_unknown_group_contract
    delete '/api/groups/Missing'

    assert_equal 404, last_response.status
    assert_equal({ 'error' => 'Group not found' }, JSON.parse(last_response.body))
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

  def test_group_membership_rejects_unknown_group_or_clip
    post '/api/group/Missing/add', JSON.generate({ clip_id: 'clip1' }), 'CONTENT_TYPE' => 'application/json'
    assert_equal 400, last_response.status

    post '/api/group/Group1/add', JSON.generate({ clip_id: 'missing' }), 'CONTENT_TYPE' => 'application/json'
    assert_equal 400, last_response.status

    post '/api/group/Missing/remove', JSON.generate({ clip_id: 'clip1' }), 'CONTENT_TYPE' => 'application/json'
    assert_equal 400, last_response.status
  end

  def test_post_api_export_requires_group
    post '/api/export', JSON.generate({ group: nil }), 'CONTENT_TYPE' => 'application/json'
    assert_equal 400, last_response.status
  end

  def test_post_api_export_success_contract
    fake_exporter = Object.new
    fake_exporter.define_singleton_method(:export_group) do |group, basename|
      raise 'unexpected arguments' unless group == 'Group1' && basename == 'episode'
      ['/project/exports/episode.mp4', '/project/exports/episode.kdenlive']
    end
    original_new = InvasionStudio::ProjectExporter.method(:new)
    InvasionStudio::ProjectExporter.define_singleton_method(:new) { |*_args, **_options| fake_exporter }

    post '/api/export', JSON.generate({ group: 'Group1', output_basename: 'episode' }), 'CONTENT_TYPE' => 'application/json'

    assert last_response.ok?
    assert_equal({
      'success' => true,
      'spliced' => '/project/exports/episode.mp4',
      'kdenlive' => '/project/exports/episode.kdenlive'
    }, JSON.parse(last_response.body))
  ensure
    InvasionStudio::ProjectExporter.define_singleton_method(:new, original_new) if original_new
  end

  def test_post_api_export_failure_contract
    fake_exporter = Object.new
    fake_exporter.define_singleton_method(:export_group) { |*_args| raise InvasionStudio::Error, 'export failed' }
    original_new = InvasionStudio::ProjectExporter.method(:new)
    InvasionStudio::ProjectExporter.define_singleton_method(:new) { |*_args, **_options| fake_exporter }

    post '/api/export', JSON.generate({ group: 'Group1' }), 'CONTENT_TYPE' => 'application/json'

    assert_equal 500, last_response.status
    assert_equal({ 'error' => 'export failed' }, JSON.parse(last_response.body))
  ensure
    InvasionStudio::ProjectExporter.define_singleton_method(:new, original_new) if original_new
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

  # ========== Upload Routes ==========

  def test_post_api_upload_creates_clip_record
    mock_video_metadata
    file_path = File.join(@folder, 'upload.mp4')
    File.write(file_path, 'video bytes')

    post '/api/upload', { 'files' => Rack::Test::UploadedFile.new(file_path, 'video/mp4') }

    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 1, data['imported']
    assert data['clips'].any? { |id| id.start_with?('clips/upload') }
    assert File.exist?(File.join(@folder, 'clips', 'upload.mp4'))
  ensure
    restore_video_new
  end

  def test_post_api_upload_imports_multiple_files
    mock_video_metadata
    path1 = File.join(@folder, 'upload1.mp4')
    path2 = File.join(@folder, 'upload2.mp4')
    File.write(path1, 'first video')
    File.write(path2, 'second video')

    post '/api/upload', { 'files' => [
      Rack::Test::UploadedFile.new(path1, 'video/mp4'),
      Rack::Test::UploadedFile.new(path2, 'video/mp4')
    ] }

    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 2, data['imported']
    assert File.exist?(File.join(@folder, 'clips', 'upload1.mp4'))
    assert File.exist?(File.join(@folder, 'clips', 'upload2.mp4'))
  ensure
    restore_video_new
  end

  def test_post_api_upload_rejects_invalid_file_with_per_file_error
    file_path = File.join(@folder, 'notes.txt')
    File.write(file_path, 'not a video')

    post '/api/upload', { 'files' => Rack::Test::UploadedFile.new(file_path, 'text/plain') }

    assert_equal 422, last_response.status
    data = JSON.parse(last_response.body)
    assert_equal false, data['success']
    assert_equal 0, data['imported']
    assert_equal 1, data['errors'].length
    assert_equal 'notes.txt', data['errors'].first['filename']
    assert_match(/Unsupported file type/, data['errors'].first['error'])
    refute File.exist?(File.join(@folder, 'clips', 'notes.txt'))
  end

  def test_post_api_upload_reports_partial_success
    mock_video_metadata
    good = File.join(@folder, 'good.mp4')
    bad = File.join(@folder, 'bad.txt')
    File.write(good, 'video bytes')
    File.write(bad, 'not a video')

    post '/api/upload', { 'files' => [
      Rack::Test::UploadedFile.new(good, 'video/mp4'),
      Rack::Test::UploadedFile.new(bad, 'text/plain')
    ] }

    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal false, data['success']
    assert_equal 1, data['imported']
    assert_equal 1, data['errors'].length
    assert_equal 'bad.txt', data['errors'].first['filename']
    assert File.exist?(File.join(@folder, 'clips', 'good.mp4'))
  ensure
    restore_video_new
  end

  def test_api_clip_handles_slash_in_clip_id
    mock_video_metadata
    file_path = File.join(@folder, 'upload.mp4')
    File.write(file_path, 'video bytes')

    post '/api/upload', { 'files' => Rack::Test::UploadedFile.new(file_path, 'video/mp4') }
    clip_id = JSON.parse(last_response.body)['clips'].first

    get '/api/clip/' + URI.encode_www_form_component(clip_id)
    assert last_response.ok?
    clip = JSON.parse(last_response.body)
    assert_equal clip_id, clip['id']

    get '/clip/' + URI.encode_www_form_component(clip['filename'])
    assert last_response.ok?
    assert_equal 'video bytes', last_response.body
  ensure
    restore_video_new
  end

  def test_thumbnail_url_in_clip_response
    File.write(File.join(@folder, 'clip.mp4'), 'dummy')
    File.write(File.join(@folder, 'thumb.jpg'), 'dummy')
    project = InvasionStudio::Project.new(@folder)
    project.storage.store(File.join(@folder, 'thumb.jpg'), 'thumbnails/clip.jpg')
    project.clip_repository.update('clip', 'thumbnail_path' => 'thumbnails/clip.jpg')
    InvasionStudio::Webui::Server.set :project, project

    get '/api/clips'
    clip = JSON.parse(last_response.body).first
    assert_equal '/thumbnail/clip', clip['thumbnail_url']

    get '/thumbnail/clip'
    assert last_response.ok?
    assert_equal 'dummy', last_response.body
  end

  def test_thumbnail_route_returns_404_when_no_thumbnail
    File.write(File.join(@folder, 'clip.mp4'), 'dummy')
    InvasionStudio::Webui::Server.set :project, InvasionStudio::Project.new(@folder)

    get '/thumbnail/clip'
    assert_equal 404, last_response.status
  end

  private

  def upload_batch_sizes(sizes)
    helper = File.expand_path(
      '../lib/invasion_studio/webui/frontend/upload_batches.mjs', __dir__
    )
    script = <<~'JAVASCRIPT'
      import { pathToFileURL } from 'node:url'
      const { partitionUploadBatches } = await import(pathToFileURL(process.argv[1]))
      const files = JSON.parse(process.argv[2]).map(size => ({ size }))
      console.log(JSON.stringify(partitionUploadBatches(files).map(batch => batch.map(file => file.size))))
    JAVASCRIPT
    stdout, stderr, status = Open3.capture3(
      'node', '--input-type=module', '--eval', script, helper, JSON.generate(sizes)
    )
    assert status.success?, stderr
    JSON.parse(stdout)
  end

  def upload_progress_percent(values)
    helper = File.expand_path(
      '../lib/invasion_studio/webui/frontend/upload_batches.mjs', __dir__
    )
    script = <<~'JAVASCRIPT'
      import { pathToFileURL } from 'node:url'
      const { uploadProgressPercent } = await import(pathToFileURL(process.argv[1]))
      console.log(uploadProgressPercent(JSON.parse(process.argv[2])))
    JAVASCRIPT
    arguments = values.transform_keys { |key| key.to_s.gsub(/_([a-z])/) { Regexp.last_match(1).upcase } }
    stdout, stderr, status = Open3.capture3(
      'node', '--input-type=module', '--eval', script, helper, JSON.generate(arguments)
    )
    assert status.success?, stderr
    stdout.to_i
  end

  def mock_video_metadata
    @original_video_new = InvasionStudio::Video.method(:new)
    InvasionStudio::Video.define_singleton_method(:new) do |path|
      obj = Object.new
      def obj.metadata
        { duration: 10.0, width: 1920, height: 1080, fps: 30, video_codec: 'h264', audio_codec: 'aac' }
      end
      obj
    end
  end

  def restore_video_new
    InvasionStudio::Video.define_singleton_method(:new, @original_video_new) if @original_video_new
  end
end
