require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestGroupRepository < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db = InvasionStudio::Database.migrate_to_current!(@tmp_dir)
    @storage = InvasionStudio::Storage::LocalDiskStorage.new(@tmp_dir)
    @clip_repository = InvasionStudio::Database::ClipRepository.new(@db, @storage)
    @repository = InvasionStudio::Database::GroupRepository.new(@db, clip_repository: @clip_repository)
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

  def test_create_and_list_groups
    assert @repository.create('Video 1')
    assert @repository.create('Video 2')

    groups = @repository.all
    assert_equal 2, groups.length
    assert_equal ['Video 1', 'Video 2'], groups.map { |g| g['name'] }
  end

  def test_create_duplicate_fails
    @repository.create('Video 1')
    refute @repository.create('Video 1')
  end

  def test_create_empty_name_fails
    refute @repository.create('')
    refute @repository.create('   ')
  end

  def test_rename_group
    @repository.create('Old')
    assert @repository.rename('Old', 'New')
    assert @repository.find('New')
    assert_nil @repository.find('Old')
  end

  def test_rename_to_existing_fails
    @repository.create('A')
    @repository.create('B')
    refute @repository.rename('A', 'B')
  end

  def test_delete_group
    @repository.create('ToDelete')
    assert @repository.delete('ToDelete')
    assert_equal [], @repository.all
  end

  def test_add_and_remove_clip
    create_clip('a.mp4')
    @repository.create('Best')

    assert @repository.add_clip('Best', 'a')
    assert_equal ['a'], @repository.find('Best')['clip_ids']

    assert @repository.remove_clip('Best', 'a')
    assert_equal [], @repository.find('Best')['clip_ids']
  end

  def test_add_clip_to_unknown_group_fails
    create_clip('a.mp4')
    refute @repository.add_clip('Missing', 'a')
  end

  def test_add_unknown_clip_fails
    @repository.create('Best')
    refute @repository.add_clip('Best', 'missing')
  end

  def test_reorder_group
    create_clip('a.mp4')
    create_clip('b.mp4')
    create_clip('c.mp4')
    @repository.create('Video')
    @repository.add_clip('Video', 'a')
    @repository.add_clip('Video', 'b')
    @repository.add_clip('Video', 'c')

    assert @repository.reorder('Video', 0, 2)
    assert_equal ['b', 'c', 'a'], @repository.find('Video')['clip_ids']
  end

  def test_reorder_invalid_index_fails
    create_clip('a.mp4')
    @repository.create('Video')
    @repository.add_clip('Video', 'a')

    refute @repository.reorder('Video', 0, 5)
  end

  def test_moves_clip_between_groups
    create_clip('a.mp4')
    @repository.create('Source')
    @repository.create('Destination')
    @repository.add_clip('Source', 'a')

    assert @repository.move_clip('Source', 'Destination', 'a')
    assert_empty @repository.find('Source')['clip_ids']
    assert_equal %w[a], @repository.find('Destination')['clip_ids']
  end

  def test_move_rejects_missing_membership_or_destination
    create_clip('a.mp4')
    @repository.create('Source')

    refute @repository.move_clip('Source', 'Missing', 'a')
    refute @repository.move_clip('Source', 'Source', 'a')
  end

  def test_clips_excludes_deleted
    create_clip('a.mp4')
    create_clip('b.mp4')
    @repository.create('Video')
    @repository.add_clip('Video', 'a')
    @repository.add_clip('Video', 'b')
    @clip_repository.mark_deleted('b', deleted_path: '.trashed/b.mp4')

    assert_equal ['a'], @repository.clips('Video').map { |c| c['id'] }
  end

  def test_names_for_clip
    create_clip('a.mp4')
    @repository.create('Best')
    @repository.create('Worst')
    @repository.add_clip('Best', 'a')
    @repository.add_clip('Worst', 'a')

    assert_equal ['Best', 'Worst'], @repository.names_for_clip('a').sort
  end

  def test_prune_removes_dangling_memberships
    create_clip('a.mp4')
    @repository.create('Video')
    @repository.add_clip('Video', 'a')

    @repository.prune([])
    assert_equal [], @repository.find('Video')['clip_ids']
  end
end
