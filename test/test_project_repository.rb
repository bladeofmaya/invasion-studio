require 'test_helper'

class TestProjectRepository < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @project_path = File.join(@directory, 'project.json')
  end

  def teardown
    FileUtils.rm_rf(@directory)
  end

  def test_initializes_versioned_project_data
    repository = InvasionStudio::ProjectRepository.new(@directory, clock: fixed_clock)

    data = repository.load_or_initialize

    assert_equal InvasionStudio::ProjectSchema::CURRENT_VERSION, data['schema_version']
    assert_equal File.basename(@directory), data['project']
    assert_equal '2026-07-26T10:00:00Z', data['created_at']
    assert_equal [{ 'name' => 'Video 1', 'clip_ids' => [] }], data['groups']
  end

  def test_migrates_unversioned_data
    File.write(@project_path, JSON.generate({
      'project' => 'legacy',
      'clips' => [],
      'groups' => []
    }))
    repository = InvasionStudio::ProjectRepository.new(@directory, clock: fixed_clock)

    data = repository.load_or_initialize

    assert_equal InvasionStudio::ProjectSchema::CURRENT_VERSION, data['schema_version']
    assert_equal 'legacy', data['project']
    assert_equal [], data['clips']
  end

  def test_rejects_newer_schema_version
    File.write(@project_path, JSON.generate({
      'schema_version' => InvasionStudio::ProjectSchema::CURRENT_VERSION + 1,
      'project' => 'future',
      'clips' => [],
      'groups' => []
    }))
    repository = InvasionStudio::ProjectRepository.new(@directory)

    assert_raises(InvasionStudio::UnsupportedProjectVersion) do
      repository.load_or_initialize
    end
  end

  def test_save_updates_timestamp_and_writes_schema_version
    repository = InvasionStudio::ProjectRepository.new(@directory, clock: fixed_clock)
    data = repository.load_or_initialize
    data['groups'] << { 'name' => 'Saved', 'clip_ids' => [] }

    repository.save(data)

    persisted = JSON.parse(File.read(@project_path))
    assert_equal '2026-07-26T10:00:00Z', persisted['updated_at']
    assert_equal InvasionStudio::ProjectSchema::CURRENT_VERSION, persisted['schema_version']
    assert_equal 'Saved', persisted['groups'].last['name']
  end

  def test_atomic_store_preserves_previous_file_when_serialization_fails
    store = InvasionStudio::AtomicJsonStore.new(@project_path)
    store.write('value' => 'original')

    assert_raises(JSON::GeneratorError) do
      store.write('invalid' => Float::NAN)
    end

    assert_equal({ 'value' => 'original' }, store.read)
    assert_equal [], Dir.glob(File.join(@directory, '.project.json.*.tmp'))
  end

  def test_atomic_store_preserves_previous_file_when_rename_fails
    store = InvasionStudio::AtomicJsonStore.new(@project_path)
    store.write('value' => 'original')
    original_rename = File.method(:rename)
    File.define_singleton_method(:rename) { |*_args| raise Errno::EIO, 'rename failed' }

    assert_raises(Errno::EIO) { store.write('value' => 'replacement') }

    assert_equal({ 'value' => 'original' }, store.read)
    assert_equal [], Dir.glob(File.join(@directory, '.project.json.*.tmp'))
  ensure
    File.define_singleton_method(:rename, original_rename) if original_rename
  end

  private

  def fixed_clock
    -> { Time.utc(2026, 7, 26, 10, 0, 0) }
  end
end
