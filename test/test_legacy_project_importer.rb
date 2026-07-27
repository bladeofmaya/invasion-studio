require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestLegacyProjectImporter < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @db = InvasionStudio::Database.migrate_to_current!(@tmp_dir)
    @storage = InvasionStudio::Storage::LocalDiskStorage.new(@tmp_dir)
    @importer = InvasionStudio::Database::LegacyProjectImporter.new(@db, @tmp_dir)
  end

  def teardown
    @db.disconnect
    FileUtils.rm_rf(@tmp_dir)
  end

  def write_legacy(data)
    File.write(File.join(@tmp_dir, 'project.json'), JSON.generate(data))
  end

  def test_imports_clips_and_groups
    File.write(File.join(@tmp_dir, 'clip1.mp4'), 'video')
    File.write(File.join(@tmp_dir, 'clip2.mp4'), 'video')
    write_legacy({
      'schema_version' => 1,
      'project' => 'legacy',
      'created_at' => '2026-07-26T10:00:00Z',
      'updated_at' => '2026-07-26T10:00:00Z',
      'clips' => [
        {
          'id' => 'clip1', 'filename' => 'clip1.mp4', 'path' => 'clip1.mp4',
          'title' => 'First', 'note' => 'note one', 'rating' => 4,
          'result' => 'win', 'cuts' => [{ 'start' => 1.0, 'end' => 2.0 }],
          'deleted' => false
        },
        {
          'id' => 'clip2', 'filename' => 'clip2.mp4', 'path' => 'clip2.mp4',
          'title' => nil, 'note' => '', 'rating' => 0,
          'result' => nil, 'cuts' => [],
          'deleted' => false
        }
      ],
      'groups' => [
        { 'name' => 'Video 1', 'clip_ids' => ['clip1'] },
        { 'name' => 'Best', 'clip_ids' => ['clip1', 'clip2'] }
      ]
    })

    assert @importer.run_if_needed

    project = InvasionStudio::Project.new(@tmp_dir, database: @db)
    assert_equal 2, project.clips.length
    clip1 = project.find_clip('clip1')
    assert_equal 'First', clip1['title']
    assert_equal 'note one', clip1['note']
    assert_equal 4, clip1['rating']
    assert_equal 'win', clip1['result']
    assert_equal [{ 'start' => 1.0, 'end' => 2.0 }], clip1['cuts']

    group_names = project.groups.map { |g| g['name'] }
    assert_includes group_names, 'Video 1'
    assert_includes group_names, 'Best'
    assert_equal ['clip1'], project.group_clips('Video 1').map { |c| c['id'] }
    assert_equal %w[clip1 clip2], project.group_clips('Best').map { |c| c['id'] }
  end

  def test_imports_deleted_clips
    File.write(File.join(@tmp_dir, 'clip1.mp4'), 'video')
    trashed_path = File.join(@tmp_dir, '.trashed', 'clip1.mp4')
    FileUtils.mkdir_p(File.dirname(trashed_path))
    File.write(trashed_path, 'trashed')
    write_legacy({
      'clips' => [
        {
          'id' => 'clip1', 'filename' => 'clip1.mp4', 'path' => 'clip1.mp4',
          'deleted' => true, 'trash_path' => '.trashed/clip1.mp4'
        }
      ],
      'groups' => []
    })

    assert @importer.run_if_needed

    project = InvasionStudio::Project.new(@tmp_dir, database: @db)
    assert_equal 0, project.clips.length
    assert_equal 1, project.deleted_clips.length
    assert project.find_clip('clip1')['deleted']
  end

  def test_does_not_import_twice
    File.write(File.join(@tmp_dir, 'clip1.mp4'), 'video')
    write_legacy({
      'clips' => [{ 'id' => 'clip1', 'filename' => 'clip1.mp4', 'path' => 'clip1.mp4' }],
      'groups' => []
    })

    assert @importer.run_if_needed
    refute @importer.run_if_needed
  end

  def test_does_nothing_when_no_legacy_file
    refute @importer.run_if_needed
    assert_equal 0, @db[:clips].count
  end

  def test_handles_unversioned_legacy_data
    File.write(File.join(@tmp_dir, 'clip1.mp4'), 'video')
    write_legacy({
      'project' => 'legacy',
      'clips' => [{ 'id' => 'clip1', 'filename' => 'clip1.mp4', 'path' => 'clip1.mp4' }],
      'groups' => [{ 'name' => 'Video 1', 'clip_ids' => ['clip1'] }]
    })

    assert @importer.run_if_needed

    project = InvasionStudio::Project.new(@tmp_dir, database: @db)
    assert_equal 1, project.clips.length
    assert_equal ['Video 1'], project.groups.map { |g| g['name'] }
  end

  def test_ignores_corrupt_project_json
    File.write(File.join(@tmp_dir, 'project.json'), '{')

    refute @importer.run_if_needed
    assert_equal 0, @db[:clips].count
  end

  def test_project_constructor_triggers_import
    File.write(File.join(@tmp_dir, 'clip1.mp4'), 'video')
    write_legacy({
      'clips' => [{ 'id' => 'clip1', 'filename' => 'clip1.mp4', 'path' => 'clip1.mp4' }],
      'groups' => [{ 'name' => 'Video 1', 'clip_ids' => ['clip1'] }]
    })

    project = InvasionStudio::Project.new(@tmp_dir)
    assert_equal 1, project.clips.length
    assert_equal 'clip1', project.clips.first['id']
  end
end
