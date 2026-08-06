require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestProject < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db_path = File.join(@tmp_dir, 'project.db')
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def create_clip_file(name)
    path = File.join(@tmp_dir, name)
    File.write(path, 'dummy')
    path
  end

  def test_initializes_with_empty_folder
    project = InvasionStudio::Project.new(@tmp_dir)
    assert File.exist?(@db_path)
    assert_equal File.basename(@tmp_dir), project.data['project']
    assert_equal [], project.clips
  end

  def test_video_settings_default_to_four_tracks_with_track_four_selected
    project = InvasionStudio::Project.new(@tmp_dir)

    assert_equal({ 'audio_track_count' => 4, 'default_audio_track' => 4 }, project.video_settings)
  end

  def test_video_settings_are_persisted
    project = InvasionStudio::Project.new(@tmp_dir)

    assert project.update_video_settings(audio_track_count: 2, default_audio_track: 1)

    reopened = InvasionStudio::Project.new(@tmp_dir)
    assert_equal({ 'audio_track_count' => 2, 'default_audio_track' => 1 }, reopened.video_settings)
  end

  def test_video_settings_reject_invalid_track_values
    project = InvasionStudio::Project.new(@tmp_dir)

    refute project.update_video_settings(audio_track_count: 0, default_audio_track: 1)
    refute project.update_video_settings(audio_track_count: 2, default_audio_track: 3)
    refute project.update_video_settings(audio_track_count: 'two', default_audio_track: 1)
    assert_equal({ 'audio_track_count' => 4, 'default_audio_track' => 4 }, project.video_settings)
  end

  def test_discovers_clips_on_disk
    create_clip_file('invasion_00001.mp4')
    create_clip_file('invasion_00002.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)

    assert_equal 2, project.clips.length
    assert_equal 'invasion_00001', project.clips[0]['id']
    assert_equal 'invasion_00002', project.clips[1]['id']
  end

  def test_creates_default_group
    project = InvasionStudio::Project.new(@tmp_dir)
    assert_equal 1, project.groups.length
    assert_equal 'Video 1', project.groups[0]['name']
  end

  def test_create_group
    project = InvasionStudio::Project.new(@tmp_dir)
    assert project.create_group('Video 2')
    assert_equal 2, project.groups.length
    assert_equal 'Video 2', project.groups[1]['name']
  end

  def test_create_duplicate_group_fails
    project = InvasionStudio::Project.new(@tmp_dir)
    refute project.create_group('Video 1')
  end

  def test_create_group_rejects_unsafe_folder_names_and_case_insensitive_duplicates
    project = InvasionStudio::Project.new(@tmp_dir)

    refute project.create_group('bad/name')
    assert project.create_group('Best Runs')
    refute project.create_group('best runs')
  end

  def test_delete_group
    project = InvasionStudio::Project.new(@tmp_dir)
    project.create_group('Video 2')
    project.delete_group('Video 2')
    assert_equal 1, project.groups.length
  end

  def test_add_and_remove_clip_from_group
    create_clip_file('invasion_00001.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.create_group('Best')

    assert project.add_clip_to_group('Best', 'invasion_00001')
    assert_equal ['invasion_00001'], project.groups.find { |g| g['name'] == 'Best' }['clip_ids']

    assert project.remove_clip_from_group('Best', 'invasion_00001')
    assert_equal [], project.groups.find { |g| g['name'] == 'Best' }['clip_ids']
  end

  def test_rejects_nonexistent_clip_group_membership
    project = InvasionStudio::Project.new(@tmp_dir)

    refute project.add_clip_to_group('Video 1', 'missing')
  end

  def test_resolve_clip_path_rejects_paths_outside_project
    project = InvasionStudio::Project.new(@tmp_dir)

    assert_nil project.resolve_clip_path('path' => '../outside.mp4')
    assert_nil project.resolve_clip_path('path' => '/tmp/outside.mp4')
  end

  def test_update_cuts_normalizes_and_merges_overlaps
    create_clip_file('test.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)

    assert project.update_cuts('test', [
      { 'start' => 4, 'end' => 8 },
      { 'start' => 1, 'end' => 5 }
    ])
    assert_equal [{ 'start' => 1.0, 'end' => 8.0 }], project.find_clip('test')['cuts']
  end

  def test_update_cuts_rejects_invalid_values
    create_clip_file('test.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)

    refute project.update_cuts('test', [{ 'start' => -1, 'end' => 2 }])
    refute project.update_cuts('test', [{ 'start' => 2, 'end' => 2 }])
    refute project.update_cuts('test', 'not-an-array')
  end

  def test_effective_duration_subtracts_saved_cuts
    create_clip_file('test.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.update_cuts('test', [
      { 'start' => 1.0, 'end' => 3.5 },
      { 'start' => 8.0, 'end' => 12.0 }
    ])

    assert_in_delta 13.5, project.effective_duration(project.find_clip('test'), 20.0)
  end

  def test_effective_duration_clamps_cuts_to_video_duration
    create_clip_file('test.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.update_cuts('test', [{ 'start' => 8.0, 'end' => 20.0 }])

    assert_in_delta 8.0, project.effective_duration(project.find_clip('test'), 10.0)
  end

  def test_reorder_group
    create_clip_file('a.mp4')
    create_clip_file('b.mp4')
    create_clip_file('c.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)

    project.add_clip_to_group('Video 1', 'a')
    project.add_clip_to_group('Video 1', 'b')
    project.add_clip_to_group('Video 1', 'c')

    assert project.reorder_group('Video 1', 0, 2)
    ids = project.groups.find { |g| g['name'] == 'Video 1' }['clip_ids']
    assert_equal ['b', 'c', 'a'], ids
  end

  def test_reorder_group_invalid_index
    create_clip_file('a.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.add_clip_to_group('Video 1', 'a')
    refute project.reorder_group('Video 1', 0, 5)
  end

  def test_move_clip_between_groups
    create_clip_file('a.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.create_group('Destination')
    project.add_clip_to_group('Video 1', 'a')

    assert project.move_clip_between_groups('Video 1', 'Destination', 'a')
    assert_empty project.groups.find { |group| group['name'] == 'Video 1' }['clip_ids']
    assert_equal %w[a], project.groups.find { |group| group['name'] == 'Destination' }['clip_ids']
  end

  def test_update_note
    create_clip_file('invasion_00001.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    assert project.update_note('invasion_00001', 'Great parry')
    assert_equal 'Great parry', project.find_clip('invasion_00001')['note']
  end

  def test_delete_clip_moves_to_trash
    create_clip_file('invasion_00001.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    clip = project.clips[0]
    resolved_path = project.resolve_clip_path(clip)

    assert project.delete_clip('invasion_00001')
    refute File.exist?(resolved_path)
    assert File.exist?(File.join(@tmp_dir, '.trashed', 'invasion_00001.mp4'))
    assert project.find_clip('invasion_00001')['deleted']
    assert_equal [], project.clips
  end

  def test_empty_trash_purges_deleted_clips_files_thumbnails_and_tags
    create_clip_file('invasion_00001.mp4')
    create_clip_file('invasion_00002.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    thumb = File.join(@tmp_dir, 'thumbnails', 'invasion_00001.jpg')
    FileUtils.mkdir_p(File.dirname(thumb))
    File.write(thumb, 'thumb')
    project.clip_repository.update('invasion_00001', 'thumbnail_path' => 'thumbnails/invasion_00001.jpg')
    project.add_tag('invasion_00001', 'solo')
    project.delete_clip('invasion_00001')

    assert_equal 1, project.empty_trash

    refute File.exist?(File.join(@tmp_dir, '.trashed', 'invasion_00001.mp4'))
    refute File.exist?(thumb)
    assert_nil project.find_clip('invasion_00001')
    assert_equal [], project.deleted_clips
    assert_equal [], project.tags
    assert_equal 1, project.clips.length
  end

  def test_empty_trash_with_nothing_deleted_is_a_noop
    create_clip_file('invasion_00001.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)

    assert_equal 0, project.empty_trash
    assert_equal 1, project.clips.length
  end

  def test_restore_clip
    create_clip_file('invasion_00001.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    clip = project.clips[0]
    resolved_path = project.resolve_clip_path(clip)

    project.delete_clip('invasion_00001')
    assert project.restore_clip('invasion_00001')
    assert File.exist?(resolved_path)
    refute project.find_clip('invasion_00001')['deleted']
    assert_equal 1, project.clips.length
  end

  def test_group_clips
    create_clip_file('a.mp4')
    create_clip_file('b.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.create_group('Best')
    project.add_clip_to_group('Best', 'a')
    project.add_clip_to_group('Best', 'b')

    group_clips = project.group_clips('Best')
    assert_equal 2, group_clips.length
    assert_equal 'a.mp4', group_clips[0]['filename']
    assert_equal 'b.mp4', group_clips[1]['filename']
  end

  def test_group_clip_paths
    create_clip_file('a.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.add_clip_to_group('Video 1', 'a')

    paths = project.group_clip_paths('Video 1')
    assert_equal [File.join(@tmp_dir, 'a.mp4')], paths
  end

  def test_persists_to_database
    create_clip_file('a.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.update_note('a', 'note')

    db = InvasionStudio::Database.connect(@db_path)
    note = db[:clips].where(id: 'a').get(:note)
    assert_equal 'note', note
  end

  def test_sync_removes_missing_clips
    create_clip_file('a.mp4')
    create_clip_file('b.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    assert_equal 2, project.clips.length

    File.delete(File.join(@tmp_dir, 'a.mp4'))
    File.delete(File.join(@tmp_dir, 'b.mp4'))
    project2 = InvasionStudio::Project.new(@tmp_dir)
    assert_equal [], project2.clips
  end

  def test_sync_keeps_trashed_clips_in_database
    create_clip_file('a.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.delete_clip('a')
    File.delete(File.join(@tmp_dir, '.trashed', 'a.mp4'))

    project2 = InvasionStudio::Project.new(@tmp_dir)
    assert_equal [], project2.all_clips
  end

  def test_sync_relocates_clips_moved_to_clips_subfolder
    create_clip_file('a.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.update_note('a', 'moved clip')

    clips_dir = File.join(@tmp_dir, 'clips')
    FileUtils.mkdir_p(clips_dir)
    FileUtils.mv(File.join(@tmp_dir, 'a.mp4'), File.join(clips_dir, 'a.mp4'))

    project2 = InvasionStudio::Project.new(@tmp_dir)
    assert_equal 1, project2.clips.length
    clip = project2.find_clip('a')
    assert_equal 'clips/a.mp4', clip['path']
    assert_equal 'moved clip', clip['note']
  end

  def test_sync_discovers_new_clips_in_clips_subfolder
    clips_dir = File.join(@tmp_dir, 'clips')
    FileUtils.mkdir_p(clips_dir)
    File.write(File.join(clips_dir, 'a.mp4'), 'dummy')

    project = InvasionStudio::Project.new(@tmp_dir)
    assert_equal 1, project.clips.length
    assert_equal 'clips/a.mp4', project.find_clip('a')['path']
  end

  def test_sync_keeps_root_clips_and_clips_subfolder_clips
    create_clip_file('a.mp4')
    clips_dir = File.join(@tmp_dir, 'clips')
    FileUtils.mkdir_p(clips_dir)
    File.write(File.join(clips_dir, 'b.mp4'), 'dummy')

    project = InvasionStudio::Project.new(@tmp_dir)
    assert_equal 2, project.clips.length
    assert_includes project.clips.map { |c| c['id'] }, 'a'
    assert_includes project.clips.map { |c| c['id'] }, 'b'
  end

  def test_delete_uses_unique_trash_path_when_filename_already_exists
    create_clip_file('a.mp4')
    trash_dir = File.join(@tmp_dir, '.trashed')
    FileUtils.mkdir_p(trash_dir)
    File.write(File.join(trash_dir, 'a.mp4'), 'older deletion')
    project = InvasionStudio::Project.new(@tmp_dir)

    assert project.delete_clip('a')

    clip = project.find_clip('a')
    refute_equal '.trashed/a.mp4', clip['trash_path']
    assert_equal 'older deletion', File.read(File.join(trash_dir, 'a.mp4'))
    assert_equal 'dummy', File.read(File.join(@tmp_dir, clip['trash_path']))
  end

  def test_restore_refuses_to_overwrite_replacement_source
    create_clip_file('a.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.delete_clip('a')
    File.write(File.join(@tmp_dir, 'a.mp4'), 'replacement')

    refute project.restore_clip('a')
    assert project.find_clip('a')['deleted']
    assert_equal 'replacement', File.read(File.join(@tmp_dir, 'a.mp4'))
  end

  def test_concurrent_mutations_are_all_persisted
    project = InvasionStudio::Project.new(@tmp_dir)

    threads = 20.times.map do |index|
      Thread.new { project.create_group("Concurrent #{index}") }
    end
    threads.each(&:value)

    db = InvasionStudio::Database.connect(@db_path)
    persisted_names = db[:compilations].select_map(:name)
    20.times { |index| assert_includes persisted_names, "Concurrent #{index}" }
  end

  def test_finalize_cuts_returns_false_when_no_cuts
    create_clip_file('test.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    refute project.finalize_cuts('test')
  end

  def test_finalize_cuts_returns_false_for_invalid_clip
    project = InvasionStudio::Project.new(@tmp_dir)
    refute project.finalize_cuts('nonexistent')
  end

  def test_finalize_cuts_applies_cuts_and_clears_them
    create_clip_file('test.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.update_cuts('test', [{ 'start' => 2.0, 'end' => 4.0 }])

    orig_new = InvasionStudio::Video.method(:new)
    InvasionStudio::Video.define_singleton_method(:new) do |path|
      metadata = File.read(path) == 'finalized' ?
        { duration: 8.0, width: 1920, height: 1080, fps: 30 } :
        { duration: 10.0, width: 1920, height: 1080, fps: 30 }
      Struct.new(:metadata).new(metadata)
    end

    finalizer = ->(_source, _segments, output) {
      File.write(output, 'finalized')
      true
    }

    assert project.finalize_cuts('test', finalizer: finalizer)
    assert_equal [], project.find_clip('test')['cuts']
    assert_equal 8.0, project.find_clip('test')['duration']
    assert File.exist?(File.join(@tmp_dir, '.backup', 'test.mp4'))
    assert_equal 'finalized', File.read(File.join(@tmp_dir, 'test.mp4'))
  ensure
    InvasionStudio::Video.define_singleton_method(:new, orig_new) if orig_new
  end

  def test_finalize_cuts_clears_stale_duration_when_metadata_refresh_fails
    create_clip_file('test.mp4')
    failed_updater = Object.new
    failed_updater.define_singleton_method(:update) { |_clip_id| false }
    project = InvasionStudio::Project.new(@tmp_dir, clip_metadata_updater: failed_updater)
    project.clip_repository.update('test', 'duration' => 10.0)
    project.update_cuts('test', [{ 'start' => 2.0, 'end' => 4.0 }])

    mock_video = Struct.new(:metadata).new({ duration: 10.0 })
    original_new = InvasionStudio::Video.method(:new)
    InvasionStudio::Video.define_singleton_method(:new) { |_path| mock_video }
    finalizer = ->(_source, _segments, output) { File.write(output, 'finalized') }

    assert project.finalize_cuts('test', finalizer: finalizer)
    assert_nil project.find_clip('test')['duration']
    assert_equal [], project.find_clip('test')['cuts']
  ensure
    InvasionStudio::Video.define_singleton_method(:new, original_new) if original_new
  end

  def test_finalize_cuts_returns_false_when_finalizer_fails
    create_clip_file('test.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.update_cuts('test', [{ 'start' => 2.0, 'end' => 4.0 }])

    mock_video = Struct.new(:path).new('test.mp4')
    def mock_video.metadata; { duration: 10.0, width: 1920, height: 1080, fps: 30 }; end

    orig_new = InvasionStudio::Video.method(:new)
    InvasionStudio::Video.define_singleton_method(:new) { |path| mock_video }

    finalizer = ->(_source, _segments, _output) { false }

    refute project.finalize_cuts('test', finalizer: finalizer)
    assert_equal [{ 'start' => 2.0, 'end' => 4.0 }], project.find_clip('test')['cuts']
    assert_equal 'dummy', File.read(File.join(@tmp_dir, 'test.mp4'))
  ensure
    InvasionStudio::Video.define_singleton_method(:new, orig_new) if orig_new
  end

  def test_finalize_cuts_handles_cut_at_start
    create_clip_file('test.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.update_cuts('test', [{ 'start' => 0.0, 'end' => 3.0 }])

    mock_video = Struct.new(:path).new('test.mp4')
    def mock_video.metadata; { duration: 10.0, width: 1920, height: 1080, fps: 30 }; end

    orig_new = InvasionStudio::Video.method(:new)
    InvasionStudio::Video.define_singleton_method(:new) { |path| mock_video }

    captured_segments = nil
    finalizer = ->(_source, segments, output) {
      captured_segments = segments
      File.write(output, 'finalized')
      true
    }

    assert project.finalize_cuts('test', finalizer: finalizer)
    assert_equal [{ start: 3.0, end: 10.0 }], captured_segments
  ensure
    InvasionStudio::Video.define_singleton_method(:new, orig_new) if orig_new
  end

  def test_finalize_cuts_handles_cut_at_end
    create_clip_file('test.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.update_cuts('test', [{ 'start' => 7.0, 'end' => 10.0 }])

    mock_video = Struct.new(:path).new('test.mp4')
    def mock_video.metadata; { duration: 10.0, width: 1920, height: 1080, fps: 30 }; end

    orig_new = InvasionStudio::Video.method(:new)
    InvasionStudio::Video.define_singleton_method(:new) { |path| mock_video }

    captured_segments = nil
    finalizer = ->(_source, segments, output) {
      captured_segments = segments
      File.write(output, 'finalized')
      true
    }

    assert project.finalize_cuts('test', finalizer: finalizer)
    assert_equal [{ start: 0.0, end: 7.0 }], captured_segments
  ensure
    InvasionStudio::Video.define_singleton_method(:new, orig_new) if orig_new
  end

  def test_finalize_cuts_returns_false_when_all_video_is_cut
    create_clip_file('test.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.update_cuts('test', [{ 'start' => 0.0, 'end' => 10.0 }])

    mock_video = Struct.new(:path).new('test.mp4')
    def mock_video.metadata; { duration: 10.0, width: 1920, height: 1080, fps: 30 }; end

    orig_new = InvasionStudio::Video.method(:new)
    InvasionStudio::Video.define_singleton_method(:new) { |path| mock_video }

    refute project.finalize_cuts('test')
    assert_equal [{ 'start' => 0.0, 'end' => 10.0 }], project.find_clip('test')['cuts']
  ensure
    InvasionStudio::Video.define_singleton_method(:new, orig_new) if orig_new
  end
end
