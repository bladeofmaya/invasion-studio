require 'test_helper'

class TestGroupCollection < Minitest::Test
  def setup
    @clips = {
      'a' => { 'id' => 'a', 'deleted' => false },
      'b' => { 'id' => 'b', 'deleted' => true }
    }
    @data = [{ 'name' => 'One', 'clip_ids' => [] }]
    @groups = InvasionStudio::GroupCollection.new(@data, clip_lookup: ->(id) { @clips[id] })
  end

  def test_create_rename_and_delete
    assert @groups.create('Two')
    refute @groups.create('Two')
    assert @groups.rename('Two', 'Renamed')
    refute @groups.rename('Renamed', 'One')
    assert @groups.delete('Renamed')
    refute @groups.delete('Missing')
  end

  def test_membership_requires_existing_group_and_clip
    assert @groups.add_clip('One', 'a')
    assert @groups.add_clip('One', 'a')
    assert_equal ['a'], @data.first['clip_ids']
    refute @groups.add_clip('One', 'missing')
    refute @groups.add_clip('Missing', 'a')
    assert @groups.remove_clip('One', 'a')
    assert_equal [], @data.first['clip_ids']
  end

  def test_reorder_validates_indices
    @data.first['clip_ids'] = %w[a b c]

    assert @groups.reorder('One', 0, 2)
    assert_equal %w[b c a], @data.first['clip_ids']
    refute @groups.reorder('One', -1, 0)
    refute @groups.reorder('One', 0, 9)
  end

  def test_clips_hide_deleted_entries_and_memberships_are_queryable
    @data.first['clip_ids'] = %w[a b missing]

    assert_equal [@clips['a']], @groups.clips('One')
    assert_equal ['One'], @groups.names_for_clip('a')
  end

  def test_prune_removes_dangling_ids
    @data.first['clip_ids'] = %w[a missing]

    @groups.prune(%w[a])

    assert_equal ['a'], @data.first['clip_ids']
  end
end
