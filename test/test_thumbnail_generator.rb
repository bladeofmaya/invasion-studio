require 'test_helper'
require 'tmpdir'
require 'fileutils'

class TestThumbnailGenerator < Minitest::Test
  class ThumbnailRunner
    def initialize(success: true)
      @success = success
      @commands = []
    end

    attr_reader :commands

    def run(*command)
      @commands << { command: command }
      output_path = command.last
      FileUtils.mkdir_p(File.dirname(output_path))
      File.write(output_path, 'thumb') if @success
      @success
    end
  end

  def setup
    @tmp_dir = Dir.mktmpdir
    @db = InvasionStudio::Database.migrate_to_current!(@tmp_dir)
    @storage = InvasionStudio::Storage::LocalDiskStorage.new(@tmp_dir)
    @repository = InvasionStudio::Database::ClipRepository.new(@db, @storage)
    @project = InvasionStudio::Project.new(
      @tmp_dir,
      database: @db,
      storage: @storage,
      clip_repository: @repository,
      group_repository: InvasionStudio::Database::GroupRepository.new(@db, clip_repository: @repository)
    )
    @project.delete_group('Video 1')
  end

  def teardown
    @db.disconnect
    FileUtils.rm_rf(@tmp_dir)
  end

  def create_clip(id, filename: nil, path: id)
    full_path = File.join(@tmp_dir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, 'video')
    @repository.create(
      'id' => id,
      'filename' => filename || File.basename(path),
      'path' => path,
      'source_kind' => 'external',
      'duration' => 30
    )
  end

  def test_project_instances_share_the_mutation_lock
    other = InvasionStudio::Project.new(@tmp_dir)
    assert_same @project.instance_variable_get(:@mutation_lock), other.instance_variable_get(:@mutation_lock)
  end

  def test_preview_generation_is_a_project_mutation
    assert_includes InvasionStudio::Project::MutationLock::MUTATIONS, :generate_thumbnail
    assert_includes InvasionStudio::Project::MutationLock::MUTATIONS, :set_preview_frame
  end

  def test_project_holds_shared_lock_during_capture_and_background_job_keeps_manual_frame
    create_clip('chosen', path: 'chosen.mp4')
    runner = ThumbnailRunner.new
    lock = @project.instance_variable_get(:@mutation_lock)
    owned = []
    original = runner.method(:run)
    runner.define_singleton_method(:run) do |*args|
      owned << lock.mon_owned?
      original.call(*args)
    end
    assert @project.set_preview_frame('chosen', 12, process_runner: runner)
    other = InvasionStudio::Project.new(@tmp_dir)
    assert other.generate_thumbnail('chosen', process_runner: runner)
    assert_equal [true], owned
    assert_equal 1, runner.commands.length
    @project.delete_clip('chosen')
    refute other.set_preview_frame('chosen', 12, process_runner: runner)
    assert_equal 1, runner.commands.length
  end

  def test_selected_frame_replaces_existing_preview_without_probing_video
    create_clip('chosen', path: 'chosen.mp4')
    @repository.update('chosen', 'duration' => 30)
    runner = ThumbnailRunner.new
    generator = InvasionStudio::ThumbnailGenerator.new(@project, process_runner: runner)
    result = generator.generate_at('chosen', 12.5)
    assert result
    assert_includes runner.commands.first[:command], '00:00:12.500'
    assert_equal 'thumb', File.read(@storage.resolve(result['thumbnail_path']))
  end

  def test_failed_selected_frame_preserves_previous_preview
    create_clip('chosen', path: 'chosen.mp4')
    @repository.update('chosen', 'duration' => 30, 'thumbnail_path' => 'thumbnails/chosen.jpg')
    FileUtils.mkdir_p(File.join(@tmp_dir, 'thumbnails'))
    File.write(File.join(@tmp_dir, 'thumbnails/chosen.jpg'), 'previous')
    generator = InvasionStudio::ThumbnailGenerator.new(@project, process_runner: ThumbnailRunner.new(success: false))
    refute generator.generate_at('chosen', 12)
    assert_equal 'previous', File.read(File.join(@tmp_dir, 'thumbnails/chosen.jpg'))
  end

  def test_selected_frame_rejects_invalid_times_without_running_ffmpeg
    create_clip('chosen', path: 'chosen.mp4')
    @repository.update('chosen', 'duration' => 30)
    runner = ThumbnailRunner.new
    generator = InvasionStudio::ThumbnailGenerator.new(@project, process_runner: runner)
    [nil, '12', -1, 30, Float::NAN, Float::INFINITY].each do |time|
      refute generator.generate_at('chosen', time)
    end
    assert_empty runner.commands
  end

  def test_generates_thumbnail_and_updates_clip
    create_clip('a', path: 'a.mp4')
    runner = ThumbnailRunner.new(success: true)
    generator = InvasionStudio::ThumbnailGenerator.new(@project, process_runner: runner)

    result = generator.generate('a')
    assert result
    clip = @repository.find('a')
    assert_equal 'thumbnails/a.jpg', clip['thumbnail_path']
    assert_equal 1, runner.commands.length
    command = runner.commands.first[:command]
    assert_equal 'ffmpeg', command.first
    assert command.any? { |arg| arg.end_with?('a.mp4') }
    assert command.any? { |arg| arg.end_with?('thumbnails/a.jpg') }
  end

  def test_returns_existing_clip_when_thumbnail_already_exists
    create_clip('a', path: 'a.mp4')
    FileUtils.mkdir_p(File.join(@tmp_dir, 'thumbnails'))
    File.write(File.join(@tmp_dir, 'thumbnails', 'a.jpg'), 'thumb')
    @repository.update('a', 'thumbnail_path' => 'thumbnails/a.jpg')
    runner = ThumbnailRunner.new

    result = generator.generate('a')

    assert_equal 'a', result['id']
    assert_equal 0, runner.commands.length
  end

  def test_records_existing_thumbnail_file_missing_from_the_database
    create_clip('a', path: 'a.mp4')
    FileUtils.mkdir_p(File.join(@tmp_dir, 'thumbnails'))
    File.write(File.join(@tmp_dir, 'thumbnails', 'a.jpg'), 'thumb')
    runner = ThumbnailRunner.new
    generator = InvasionStudio::ThumbnailGenerator.new(@project, process_runner: runner)

    result = generator.generate('a')

    assert_equal 'thumbnails/a.jpg', result['thumbnail_path']
    assert_equal 'thumbnails/a.jpg', @repository.find('a')['thumbnail_path']
    assert_equal 0, runner.commands.length
  end

  def test_returns_false_when_clip_missing
    runner = TestSupport::FakeProcessRunner.new
    generator = InvasionStudio::ThumbnailGenerator.new(@project, process_runner: runner)

    refute generator.generate('missing')
    assert_equal 0, runner.commands.length
  end

  def test_returns_false_when_ffmpeg_fails
    create_clip('a', path: 'a.mp4')
    runner = ThumbnailRunner.new(success: false)
    generator = InvasionStudio::ThumbnailGenerator.new(@project, process_runner: runner)

    refute generator.generate('a')
    assert_nil @repository.find('a')['thumbnail_path']
  end

  def test_sanitizes_clip_id_for_thumbnail_key
    create_clip('clips/my-clip', path: 'clips/my-clip.mp4')
    runner = ThumbnailRunner.new(success: true)
    generator = InvasionStudio::ThumbnailGenerator.new(@project, process_runner: runner)

    generator.generate('clips/my-clip')
    clip = @repository.find('clips/my-clip')
    assert_equal 'thumbnails/clips_my-clip.jpg', clip['thumbnail_path']
  end

  def generator
    InvasionStudio::ThumbnailGenerator.new(@project)
  end
end
