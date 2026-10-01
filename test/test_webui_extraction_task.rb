require 'test_helper'
require 'ostruct'

class TestWebuiExtractionTask < Minitest::Test
  def setup
    @folder = Dir.mktmpdir
    @source = File.join(@folder, 'recording.mp4')
    File.write(@source, 'not a real video')
    @project = InvasionStudio::Project.new(File.join(@folder, 'project'))
    @jobs = []
    @options = nil
    @engine = OpenStruct.new(clip_extraction_stage: OpenStruct.new(created: []))
    @engine.define_singleton_method(:run!) {}
    @task = InvasionStudio::Webui::ExtractionTask.new(
      @project,
      executor: ->(&job) { @jobs << job },
      dependency_check: -> {},
      engine_factory: ->(paths, options) { @paths = paths; @options = options; @engine }
    )
  end

  def teardown
    FileUtils.rm_rf(@folder)
  end

  def test_runs_in_background_and_uses_current_project_and_cli_options
    state = @task.start(paths: [@source], options: { 'ffmpeg_threads' => 8, 'hwaccel' => true })
    assert_equal 'running', state[:status]
    assert_nil @options
    assert_raises(InvasionStudio::Webui::ExtractionTask::Busy) { @task.start(paths: [@source]) }
    @jobs.shift.call
    assert_equal [@source], @paths
    assert_equal File.join(@project.folder_path, 'clips'), @options[:outdir]
    assert_equal 'clip', @options[:prefix]
    assert_equal 8, @options[:ffmpeg_threads]
    assert_equal true, @options[:hwaccel]
    assert_equal 10, @options[:pad_start]
    assert_equal 'completed', @task.status[:status]
    assert_equal 0, @task.status[:imported]
  end

  def test_validates_all_files_and_options_before_scheduling
    [[@source, '/missing.mp4'], [], 'not an array'].each do |paths|
      assert_raises(InvasionStudio::Error) { @task.start(paths: paths) }
    end
    [{ 'ffmpeg_threads' => 0 }, { 'fps' => 1.5 }, { 'pad_end' => -1 },
     { 'hwaccel' => 'yes' }, { 'outdir' => '/tmp/elsewhere' }].each do |options|
      assert_raises(InvasionStudio::Error) { @task.start(paths: [@source], options: options) }
    end
    assert_empty @jobs
    assert_equal 'idle', @task.status[:status]
  end

  def test_preserves_input_order_and_deduplicates_sources
    second = File.join(@folder, 'second.mp4')
    File.write(second, 'dummy')
    @task.start(paths: [second, @source, second])
    @jobs.shift.call
    assert_equal [second, @source], @paths
  end

  def test_records_partial_results_even_when_extraction_fails
    output = File.join(@project.folder_path, 'clips', 'clip_00001.mp4')
    @engine.define_singleton_method(:run!) do
      FileUtils.mkdir_p(File.dirname(output))
      File.write(output, 'dummy')
      clip_extraction_stage.created << { path: output, source: 'recording.mp4' }
      raise InvasionStudio::Error, 'OCR failed'
    end
    @task.start(paths: [@source])
    @jobs.shift.call
    assert_equal 'failed', @task.status[:status]
    assert_equal 'OCR failed', @task.status[:error]
    assert_equal 1, @task.status[:imported]
    clip = @project.clips.first
    assert_equal 'extracted', clip['source_kind']
    assert_equal 'recording.mp4', clip['source_video']
    assert_equal 'not a real video', File.read(@source)
    @task.start(paths: [@source])
    assert_equal 'running', @task.status[:status]
  end

  def test_continues_numbering_after_existing_clips
    FileUtils.mkdir_p(File.join(@project.folder_path, 'clips'))
    File.write(File.join(@project.folder_path, 'clips', 'clip_00009.mp4'), 'dummy')
    @project.sync_clips!
    @task.start(paths: [@source])
    @jobs.shift.call
    assert_equal 9, @options[:min_clip_number]
  end

  def test_missing_dependency_is_reported_without_starting_the_engine
    task = InvasionStudio::Webui::ExtractionTask.new(
      @project, executor: ->(&job) { @jobs << job },
      dependency_check: -> { raise InvasionStudio::Error, 'Tesseract is missing' },
      engine_factory: ->(*) { flunk 'engine must not run' }
    )
    task.start(paths: [@source])
    @jobs.shift.call
    assert_equal 'failed', task.status[:status]
    assert_equal 'Tesseract is missing', task.status[:error]
    assert_equal 0, task.status[:imported]
  end

  def test_reports_stage_and_frame_progress
    @task.start(paths: [@source])
    @jobs.shift.call
    reporter = @options[:reporter]
    reporter.processing(OpenStruct.new(path: @source))
    callbacks = reporter.ocr_frame_options(nil)
    callbacks[:progress_callback].call(5, 20)
    assert_equal 'ocr', @task.status[:stage]
    assert_equal 5, @task.status[:current]
    assert_equal 20, @task.status[:total]
    reporter.scanning
    assert_equal 'scanning', @task.status[:stage]
    assert_nil @task.status[:total]
  end
end
