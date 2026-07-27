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
end
