require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestSearchClips < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db = InvasionStudio::Database.migrate_to_current!(@tmp_dir)
    @storage = InvasionStudio::Storage::LocalDiskStorage.new(@tmp_dir)
    @clips = InvasionStudio::Database::ClipRepository.new(@db, @storage)
    @groups = InvasionStudio::Database::GroupRepository.new(@db, clip_repository: @clips)
    @tags = InvasionStudio::Database::TagRepository.new(@db, clip_repository: @clips)
    @search = InvasionStudio::SearchClips.new(@db, clip_repository: @clips)
  end

  def teardown
    @db.disconnect
    FileUtils.rm_rf(@tmp_dir)
  end

  def create_clip(name, attributes = {})
    File.write(File.join(@tmp_dir, name), 'dummy')
    defaults = {
      'id' => File.basename(name, '.*'),
      'filename' => name,
      'path' => name,
      'title' => nil,
      'note' => '',
      'rating' => 0,
      'result' => nil,
      'source_kind' => 'external'
    }
    @clips.create(defaults.merge(attributes))
  end

  def set_created_at(id, timestamp)
    @db[:clips].where(id: id).update(created_at: timestamp)
  end

  def result_ids(**params)
    @search.call(**params).map { |clip| clip['id'] }
  end

  def test_defaults_to_active_clips_in_creation_order
    create_clip('b.mp4')
    create_clip('a.mp4')
    create_clip('gone.mp4')
    @clips.mark_deleted('gone')
    set_created_at('b', '2026-01-01T00:00:00Z')
    set_created_at('a', '2026-01-02T00:00:00Z')

    assert_equal %w[b a], result_ids
  end

  def test_state_deleted_returns_only_deleted_clips
    create_clip('kept.mp4')
    create_clip('gone.mp4')
    @clips.mark_deleted('gone')

    assert_equal %w[gone], result_ids(state: 'deleted')
  end

  def test_state_assigned_and_unassigned_follow_group_membership
    create_clip('grouped.mp4')
    create_clip('loose.mp4')
    @groups.create('G')
    @groups.add_clip('G', 'grouped')

    assert_equal %w[grouped], result_ids(state: 'assigned')
    assert_equal %w[loose], result_ids(state: 'unassigned')
  end

  def test_query_matches_title_case_insensitively
    create_clip('a.mp4', 'title' => 'Epic Parry')
    create_clip('b.mp4', 'title' => 'Boring')

    assert_equal %w[a], result_ids(query: 'parry')
  end

  def test_query_matches_note_and_filename
    create_clip('invasion_007.mp4', 'note' => 'triple gank')
    create_clip('other.mp4')

    assert_equal %w[invasion_007], result_ids(query: 'gank')
    assert_equal %w[invasion_007], result_ids(query: '007')
  end

  def test_tag_filter
    create_clip('a.mp4')
    create_clip('b.mp4')
    @tags.add_to_clip('a', 'Parry')

    assert_equal %w[a], result_ids(tag: 'parry')
    assert_equal [], result_ids(tag: 'unknown')
  end

  def test_min_rating_filter
    create_clip('low.mp4', 'rating' => 1)
    create_clip('high.mp4', 'rating' => 4)

    assert_equal %w[high], result_ids(min_rating: 3)
  end

  def test_result_filter
    create_clip('won.mp4', 'result' => 'win')
    create_clip('lost.mp4', 'result' => 'loss')

    assert_equal %w[won], result_ids(result: 'win')
  end

  def test_filters_combine
    create_clip('a.mp4', 'title' => 'Parry win', 'result' => 'win')
    create_clip('b.mp4', 'title' => 'Parry fail', 'result' => 'loss')

    assert_equal %w[a], result_ids(query: 'parry', result: 'win')
  end

  def test_sort_newest_and_oldest
    create_clip('old.mp4')
    create_clip('new.mp4')
    set_created_at('old', '2026-01-01T00:00:00Z')
    set_created_at('new', '2026-01-02T00:00:00Z')

    assert_equal %w[new old], result_ids(sort: 'newest')
    assert_equal %w[old new], result_ids(sort: 'oldest')
  end

  def test_sort_by_rating
    create_clip('low.mp4', 'rating' => 1)
    create_clip('high.mp4', 'rating' => 5)

    assert_equal %w[high low], result_ids(sort: 'rating-desc')
    assert_equal %w[low high], result_ids(sort: 'rating-asc')
  end

  def test_sort_by_title_falls_back_to_filename_case_insensitively
    create_clip('zzz.mp4', 'title' => 'apple')
    create_clip('Banana.mp4')
    create_clip('c.mp4', 'title' => 'Cherry')

    assert_equal %w[zzz Banana c], result_ids(sort: 'title')
  end

  def test_sort_by_duration
    create_clip('short.mp4', 'duration' => 10.0)
    create_clip('long.mp4', 'duration' => 99.0)

    assert_equal %w[long short], result_ids(sort: 'duration-desc')
    assert_equal %w[short long], result_ids(sort: 'duration-asc')
  end

  def test_blank_params_are_ignored
    create_clip('a.mp4')
    create_clip('gone.mp4')
    @clips.mark_deleted('gone')

    ids = result_ids(query: '', tag: '', min_rating: '', result: '', state: '', sort: '')
    assert_equal %w[a], ids
  end
end
