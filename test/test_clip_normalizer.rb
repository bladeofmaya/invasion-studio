require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestClipNormalizer < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db = InvasionStudio::Database.migrate_to_current!(@tmp_dir)
    @storage = InvasionStudio::Storage::LocalDiskStorage.new(@tmp_dir)
    @repository = InvasionStudio::Database::ClipRepository.new(@db, @storage)
    FileUtils.mkdir_p(File.join(@tmp_dir, 'clips'))
    FileUtils.mkdir_p(File.join(@tmp_dir, 'thumbnails'))
  end

  def teardown
    @db.disconnect
    FileUtils.rm_rf(@tmp_dir)
  end

  def normalizer
    InvasionStudio::ClipNormalizer.new(database: @db, storage: @storage, repository: @repository)
  end

  def add_clip(basename, thumbnail: true)
    File.write(File.join(@tmp_dir, 'clips', "#{basename}.mp4"), 'video')
    thumbnail_path = nil
    if thumbnail
      File.write(File.join(@tmp_dir, 'thumbnails', "#{basename}.jpg"), 'thumb')
      thumbnail_path = "thumbnails/#{basename}.jpg"
    end
    @repository.create(
      'id' => basename,
      'filename' => "#{basename}.mp4",
      'path' => "clips/#{basename}.mp4",
      'source_kind' => 'extracted',
      'thumbnail_path' => thumbnail_path
    )
  end

  def test_renames_clips_sequentially_compacting_gaps
    add_clip('str-invasions_00001')
    add_clip('str-invasions_00003')
    add_clip('str-invasions_00021')

    changes = normalizer.run

    assert_equal %w[clip_00001 clip_00002 clip_00003], changes.map { |c| c[:new_id] }
    assert File.exist?(File.join(@tmp_dir, 'clips', 'clip_00002.mp4'))
    refute File.exist?(File.join(@tmp_dir, 'clips', 'str-invasions_00003.mp4'))
    assert File.exist?(File.join(@tmp_dir, 'thumbnails', 'clip_00002.jpg'))

    clip = @repository.find('clip_00002')
    assert_equal 'clip_00002.mp4', clip['filename']
    assert_equal 'clips/clip_00002.mp4', clip['path']
    assert_equal 'thumbnails/clip_00002.jpg', clip['thumbnail_path']
    assert_nil @repository.find('str-invasions_00003')
  end

  def test_preserves_compilations_tags_and_cuts
    add_clip('str-invasions_00001')
    group_repo = InvasionStudio::Database::GroupRepository.new(@db, clip_repository: @repository)
    tag_repo = InvasionStudio::Database::TagRepository.new(@db, clip_repository: @repository)
    group_repo.create('Best of')
    group_repo.add_clip('Best of', 'str-invasions_00001')
    tag_repo.add_to_clip('str-invasions_00001', 'twinblade')
    @repository.update_cuts('str-invasions_00001', [{ 'start' => 1.0, 'end' => 2.0 }])

    normalizer.run

    assert_includes group_repo.clips('Best of').map { |c| c['id'] }, 'clip_00001'
    assert_equal %w[twinblade], @repository.tags_for('clip_00001')
    assert_equal [{ 'start' => 1.0, 'end' => 2.0 }], @repository.find('clip_00001')['cuts']
  end

  def test_is_idempotent
    add_clip('str-invasions_00001')
    normalizer.run

    assert_empty normalizer.plan
    assert_empty normalizer.run
  end

  def test_handles_swapped_numbering_without_collisions
    first = add_clip('clip_00002')
    second = add_clip('clip_00001')
    @db[:clips].where(id: first['id']).update(created_at: '2026-01-01T00:00:00Z')
    @db[:clips].where(id: second['id']).update(created_at: '2026-01-02T00:00:00Z')

    changes = normalizer.run

    assert_equal 2, changes.length
    assert_equal 'clip_00001', @repository.active.first['id']
    assert File.exist?(File.join(@tmp_dir, 'clips', 'clip_00001.mp4'))
    assert File.exist?(File.join(@tmp_dir, 'clips', 'clip_00002.mp4'))
  end

  def test_skips_trashed_clips_and_reserves_their_ids
    add_clip('str-invasions_00001')
    trashed = add_clip('clip_00001', thumbnail: false)
    @repository.mark_deleted(trashed['id'], deleted_path: '.trashed/clip_00001.mp4')

    changes = normalizer.run

    assert_equal 1, changes.length
    assert_equal 'clip_00002', changes.first[:new_id]
    assert_equal 'clip_00001', @repository.deleted.first['id']
  end

  def test_plan_does_not_touch_files_or_database
    add_clip('str-invasions_00001')

    plan = normalizer.plan

    assert_equal 1, plan.length
    assert File.exist?(File.join(@tmp_dir, 'clips', 'str-invasions_00001.mp4'))
    refute_nil @repository.find('str-invasions_00001')
  end

  def test_refuses_when_a_video_file_is_missing
    add_clip('str-invasions_00001')
    FileUtils.rm(File.join(@tmp_dir, 'clips', 'str-invasions_00001.mp4'))

    error = assert_raises(InvasionStudio::Error) { normalizer.run }
    assert_match(/missing/i, error.message)
    refute_nil @repository.find('str-invasions_00001')
  end

  def test_links_unlinked_on_disk_thumbnail
    File.write(File.join(@tmp_dir, 'clips', 'str-invasions_00001.mp4'), 'video')
    File.write(File.join(@tmp_dir, 'thumbnails', 'str-invasions_00001.jpg'), 'thumb')
    # Discovery registers clips without a thumbnail_path; the file exists anyway.
    @repository.create(
      'id' => 'str-invasions_00001',
      'filename' => 'str-invasions_00001.mp4',
      'path' => 'clips/str-invasions_00001.mp4',
      'source_kind' => 'external',
      'thumbnail_path' => nil
    )

    normalizer.run

    assert File.exist?(File.join(@tmp_dir, 'thumbnails', 'clip_00001.jpg'))
    refute File.exist?(File.join(@tmp_dir, 'thumbnails', 'str-invasions_00001.jpg'))
    assert_equal 'thumbnails/clip_00001.jpg', @repository.find('clip_00001')['thumbnail_path']
  end

  def test_clip_without_thumbnail_is_renamed
    add_clip('str-invasions_00001', thumbnail: false)

    changes = normalizer.run

    assert_equal 1, changes.length
    clip = @repository.find('clip_00001')
    assert_nil clip['thumbnail_path']
  end
end
