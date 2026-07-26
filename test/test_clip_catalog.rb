require 'test_helper'

class TestClipCatalog < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @clips = []
    @catalog = InvasionStudio::ClipCatalog.new(
      @directory,
      @clips,
      id_generator: ->(base) { "#{base}-generated" }
    )
  end

  def teardown
    FileUtils.rm_rf(@directory)
  end

  def test_sync_discovers_and_migrates_clips
    File.write(File.join(@directory, 'fight.mp4'), 'video')
    @clips << { 'id' => 'legacy', 'filename' => 'legacy.mp4', 'path' => File.join(@directory, 'legacy.mp4') }
    File.write(File.join(@directory, 'legacy.mp4'), 'video')
    groups = InvasionStudio::GroupCollection.new([], clip_lookup: ->(id) { @catalog.find(id) })

    @catalog.sync!(groups: groups)

    fight = @catalog.find('fight')
    assert_equal 'fight.mp4', fight['path']
    assert_equal '', fight['note']
    assert_equal [], fight['cuts']
    assert_equal 'legacy.mp4', @catalog.find('legacy')['path']
  end

  def test_sync_allocates_unique_id_for_duplicate_basename
    File.write(File.join(@directory, 'fight.mp4'), 'video')
    File.write(File.join(@directory, 'fight.mkv'), 'video')

    @catalog.sync!(groups: InvasionStudio::GroupCollection.new([], clip_lookup: ->(id) { @catalog.find(id) }))

    assert_equal %w[fight fight-generated], @catalog.all.map { |clip| clip['id'] }
  end

  def test_sync_keeps_clip_at_recorded_unique_trash_path
    trash_dir = File.join(@directory, '.trashed')
    FileUtils.mkdir_p(trash_dir)
    File.write(File.join(trash_dir, 'fight-old.mp4'), 'video')
    @clips << {
      'id' => 'fight', 'filename' => 'fight.mp4', 'path' => 'fight.mp4',
      'trash_path' => '.trashed/fight-old.mp4', 'deleted' => true
    }

    @catalog.sync!(groups: InvasionStudio::GroupCollection.new([], clip_lookup: ->(id) { @catalog.find(id) }))

    assert @catalog.find('fight')
  end

  def test_sync_removes_missing_clips_and_prunes_groups
    @clips << { 'id' => 'missing', 'filename' => 'missing.mp4', 'path' => 'missing.mp4' }
    group_data = [{ 'name' => 'Group', 'clip_ids' => ['missing'] }]
    groups = InvasionStudio::GroupCollection.new(group_data, clip_lookup: ->(id) { @catalog.find(id) })

    @catalog.sync!(groups: groups)

    assert_equal [], @clips
    assert_equal [], group_data.first['clip_ids']
  end

  def test_resolve_rejects_escape_and_symlink_escape
    outside = Dir.mktmpdir
    File.write(File.join(outside, 'outside.mp4'), 'video')
    File.symlink(File.join(outside, 'outside.mp4'), File.join(@directory, 'link.mp4'))

    assert_nil @catalog.resolve('../outside.mp4')
    assert_nil @catalog.resolve('link.mp4')
  ensure
    FileUtils.rm_rf(outside) if outside
  end
end
