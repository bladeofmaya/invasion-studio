require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestDatabase < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_migrate_to_current_creates_database_file
    db = InvasionStudio::Database.migrate_to_current!(@tmp_dir)

    assert File.exist?(File.join(@tmp_dir, 'project.db'))
    assert_kind_of Sequel::SQLite::Database, db
  ensure
    db&.disconnect
  end

  def test_migrations_create_expected_tables
    db = InvasionStudio::Database.migrate_to_current!(@tmp_dir)

    tables = db.tables
    assert_includes tables, :clips
    assert_includes tables, :tags
    assert_includes tables, :clip_tags
    assert_includes tables, :compilations
    assert_includes tables, :compilation_clips
    assert_includes tables, :cuts
    assert_includes tables, :schema_info
    refute_includes tables, :groups
    refute_includes tables, :group_clips
    assert_includes db[:compilation_clips].columns, :compilation_id
  ensure
    db&.disconnect
  end

  def test_connect_reuses_existing_database
    db1 = InvasionStudio::Database.migrate_to_current!(@tmp_dir)
    db1.disconnect

    db2 = InvasionStudio::Database.connect(File.join(@tmp_dir, 'project.db'))
    assert File.exist?(File.join(@tmp_dir, 'project.db'))
  ensure
    db2&.disconnect
  end

  def test_storage_paths_are_unique
    db = InvasionStudio::Database.migrate_to_current!(@tmp_dir)
    attributes = {
      title: nil, note: '', rating: 0, result: nil, source_kind: 'external',
      original_filename: 'clip.mp4', storage_path: 'clips/clip.mp4',
      created_at: Time.now.utc.iso8601, updated_at: Time.now.utc.iso8601
    }
    db[:clips].insert(attributes.merge(id: 'first'))

    assert_raises(Sequel::UniqueConstraintViolation) do
      db[:clips].insert(attributes.merge(id: 'second'))
    end
  ensure
    db&.disconnect
  end

  def test_migration_merges_existing_duplicate_storage_paths
    db_path = File.join(@tmp_dir, 'project.db')
    db = InvasionStudio::Database.connect(db_path)
    Sequel::IntegerMigrator.run(db, InvasionStudio::Database::MIGRATIONS_PATH, target: 4)
    timestamp = Time.now.utc.iso8601
    attributes = {
      title: nil, note: '', rating: 0, result: nil,
      original_filename: 'clip.mp4', storage_path: 'clips/clip.mp4',
      created_at: timestamp, updated_at: timestamp
    }
    db[:clips].insert(attributes.merge(id: 'clip', source_kind: 'external'))
    db[:clips].insert(attributes.merge(id: 'clips/clip', source_kind: 'uploaded'))

    InvasionStudio::Database.migrate(db)

    rows = db[:clips].where(storage_path: 'clips/clip.mp4').all
    assert_equal 1, rows.length
    assert_equal 'clips/clip', rows.first[:id]
    assert_equal 'uploaded', rows.first[:source_kind]
  ensure
    db&.disconnect
  end
end
