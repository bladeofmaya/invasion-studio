require 'test_helper'

class TestMarkerIdentificationTask < Minitest::Test
  def setup
    @folder = Dir.mktmpdir
    File.write(File.join(@folder, 'clip.mp4'), 'dummy')
    @project = InvasionStudio::Project.new(@folder)
    @jobs = []
    @video = Struct.new(:path, :frames, :metadata).new(
      File.join(@folder, 'clip.mp4'),
      [InvasionStudio::Frame.new(2, 'Hunter Alice has died', '00:00:02', File.join(@folder, 'clip.mp4'))],
      { duration: 10.0 }
    )
    @task = InvasionStudio::Webui::MarkerIdentificationTask.new(
      @project, executor: ->(&job) { @jobs << job }, dependency_check: -> {},
      video_factory: ->(_path, options) { assert options[:no_cache]; @video }
    )
  end

  def teardown
    FileUtils.rm_rf(@folder)
  end

  def test_background_scan_merges_and_repeat_scan_does_not_duplicate
    manual = { 'id' => 'manual', 'time' => 1.0, 'event_type' => 'custom', 'label' => 'Keep' }
    @project.update_markers('clip', [manual])
    assert_equal 'running', @task.start('clip')[:status]
    assert_raises(InvasionStudio::Webui::MarkerIdentificationTask::Busy) { @task.start('clip') }
    @jobs.shift.call
    assert_equal 'completed', @task.status[:status]
    assert_equal 1, @task.status[:added]
    assert_equal [{ 'id' => @project.find_clip('clip')['markers'].first['id'], 'time' => 0.0,
                    'event_type' => 'hunter_defeated', 'label' => 'Alice' }, manual], @project.find_clip('clip')['markers']
    @task.start('clip')
    @jobs.shift.call
    assert_equal 0, @task.status[:added]
  end

  def test_rejects_results_when_source_changes_during_scan
    @task.start('clip')
    File.write(@video.path, 'changed file')
    @jobs.shift.call
    assert_equal 'failed', @task.status[:status]
    assert_match(/changed/, @task.status[:error])
    assert_empty @project.find_clip('clip')['markers']
  end

  def test_failures_are_visible_without_losing_existing_markers
    @task.start('clip')
    @video.frames = nil
    @jobs.shift.call
    assert_equal 'failed', @task.status[:status]
    assert @task.status[:error]
  end
end
