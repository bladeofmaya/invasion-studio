require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestProject < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @project_file = File.join(@tmp_dir, 'project.json')
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
    assert File.exist?(@project_file)
    assert_equal File.basename(@tmp_dir), project.data['project']
    assert_equal [], project.clips
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

  def test_persists_to_json
    create_clip_file('a.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.update_note('a', 'note')

    data = JSON.parse(File.read(@project_file))
    assert_equal 'note', data['clips'].find { |c| c['id'] == 'a' }['note']
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

  def test_sync_keeps_trashed_clips_in_json
    create_clip_file('a.mp4')
    project = InvasionStudio::Project.new(@tmp_dir)
    project.delete_clip('a')
    File.delete(File.join(@tmp_dir, '.trashed', 'a.mp4'))

    project2 = InvasionStudio::Project.new(@tmp_dir)
    assert_equal [], project2.all_clips
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

    meta = { duration: 10.0, width: 1920, height: 1080, fps: 30 }
    mock_video = Struct.new(:path).new('test.mp4')
    def mock_video.metadata; { duration: 10.0, width: 1920, height: 1080, fps: 30 }; end

    orig_new = InvasionStudio::Video.method(:new)
    InvasionStudio::Video.define_singleton_method(:new) { |path| mock_video }

    finalizer = ->(_source, _segments, output) {
      File.write(output, 'finalized')
      true
    }

    assert project.finalize_cuts('test', finalizer: finalizer)
    assert_equal [], project.find_clip('test')['cuts']
    assert File.exist?(File.join(@tmp_dir, '.backup', 'test.mp4'))
    assert_equal 'finalized', File.read(File.join(@tmp_dir, 'test.mp4'))
  ensure
    InvasionStudio::Video.define_singleton_method(:new, orig_new) if orig_new
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
