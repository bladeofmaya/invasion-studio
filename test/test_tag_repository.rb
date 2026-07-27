require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestTagRepository < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db = InvasionStudio::Database.migrate_to_current!(@tmp_dir)
    @storage = InvasionStudio::Storage::LocalDiskStorage.new(@tmp_dir)
    @clip_repository = InvasionStudio::Database::ClipRepository.new(@db, @storage)
    @repository = InvasionStudio::Database::TagRepository.new(@db, clip_repository: @clip_repository)
  end

  def teardown
    @db.disconnect
    FileUtils.rm_rf(@tmp_dir)
  end

  def create_clip(name)
    path = File.join(@tmp_dir, name)
    File.write(path, 'dummy')
    @clip_repository.create(
      'id' => File.basename(name, '.*'),
      'filename' => name,
      'path' => name,
      'source_kind' => 'external'
    )
  end

  def test_find_or_create_creates_tag
    id = @repository.find_or_create('PvP')
    assert id
    assert_equal ['pvp'], @repository.all
  end

  def test_find_or_create_returns_existing_id
    id1 = @repository.find_or_create('PvP')
    id2 = @repository.find_or_create('pvp')
    assert_equal id1, id2
  end

  def test_find_or_create_rejects_empty_name
    assert_nil @repository.find_or_create('')
    assert_nil @repository.find_or_create('   ')
  end

  def test_add_and_remove_tag_from_clip
    create_clip('a.mp4')
    @repository.add_to_clip('a', 'win')

    assert_equal ['a'], @repository.clips_for('win').map { |c| c['id'] }
    assert_equal ['win'], @clip_repository.tags_for('a')

    @repository.remove_from_clip('a', 'win')
    assert_equal [], @clip_repository.tags_for('a')
  end

  def test_add_to_clip_normalizes_name
    create_clip('a.mp4')
    @repository.add_to_clip('a', '  PvP  ')

    assert_equal ['pvp'], @clip_repository.tags_for('a')
  end

  def test_delete_unused_removes_orphan_tags
    create_clip('a.mp4')
    @repository.add_to_clip('a', 'used')
    @repository.find_or_create('unused')

    @repository.delete_unused
    assert_equal ['used'], @repository.all
  end

  def test_clips_for_excludes_deleted
    create_clip('a.mp4')
    create_clip('b.mp4')
    @repository.add_to_clip('a', 'pvp')
    @repository.add_to_clip('b', 'pvp')
    @clip_repository.mark_deleted('b', deleted_path: '.trashed/b.mp4')

    assert_equal ['a'], @repository.clips_for('pvp').map { |c| c['id'] }
  end

  def test_details_counts_non_trashed_clips
    create_clip('a.mp4')
    create_clip('b.mp4')
    create_clip('c.mp4')
    @repository.add_to_clip('a', 'pvp')
    @repository.add_to_clip('b', 'pvp')
    @repository.add_to_clip('c', 'pvp')
    @repository.add_to_clip('a', 'ambush')
    @repository.find_or_create('lonely')
    @clip_repository.mark_deleted('c', deleted_path: '.trashed/c.mp4')

    assert_equal(
      [
        { 'name' => 'ambush', 'clip_count' => 1 },
        { 'name' => 'lonely', 'clip_count' => 0 },
        { 'name' => 'pvp', 'clip_count' => 2 }
      ],
      @repository.details
    )
  end

  def test_rename_updates_tag_and_keeps_assignments
    create_clip('a.mp4')
    @repository.add_to_clip('a', 'pvp')

    assert @repository.rename('pvp', 'Duels')
    assert_equal ['duels'], @repository.all
    assert_equal ['a'], @repository.clips_for('duels').map { |c| c['id'] }
  end

  def test_rename_rejects_missing_or_conflicting_names
    create_clip('a.mp4')
    @repository.add_to_clip('a', 'pvp')
    @repository.add_to_clip('a', 'ambush')

    refute @repository.rename('nope', 'new')
    refute @repository.rename('pvp', 'ambush')
    refute @repository.rename('pvp', '   ')
    assert @repository.rename('pvp', 'PVP')
  end

  def test_delete_removes_tag_and_clip_assignments
    create_clip('a.mp4')
    create_clip('b.mp4')
    @repository.add_to_clip('a', 'pvp')
    @repository.add_to_clip('b', 'pvp')
    @repository.add_to_clip('a', 'ambush')

    assert @repository.delete('pvp')
    assert_equal ['ambush'], @repository.all
    assert_empty @repository.clips_for('pvp')
    assert_equal ['ambush'], @clip_repository.tags_for('a')
    refute @repository.delete('pvp')
  end
end
