require 'test_helper'

class TestDependencySettings < Minitest::Test
  def setup
    @folder = Dir.mktmpdir
    @path = File.join(@folder, 'dependencies.json')
    @tool = File.join(@folder, 'custom ffmpeg')
    File.write(@tool, 'dummy executable, never run')
    File.chmod(0o755, @tool)
    @settings = InvasionStudio::DependencySettings.new(path: @path)
  end

  def teardown
    FileUtils.rm_rf(@folder)
  end

  def test_custom_paths_persist_and_take_priority_over_detected_tools
    @settings.update('ffmpeg' => @tool)
    reopened = InvasionStudio::DependencySettings.new(path: @path)
    env = { 'INVASION_STUDIO_FFMPEG' => '/bundled/ffmpeg', 'PATH' => @folder }
    assert_equal @tool, InvasionStudio::Executables.ffmpeg(env, settings: reopened)
    info = reopened.diagnostics(env).find { |tool| tool['name'] == 'ffmpeg' }
    assert_equal @tool, info['active_path']
    assert_equal '/bundled/ffmpeg', info['detected_path']
    assert_equal true, info['available']
    reopened.update('ffmpeg' => '')
    assert_equal '/bundled/ffmpeg', InvasionStudio::Executables.ffmpeg(env, settings: reopened)
  end

  def test_path_detection_and_missing_custom_path_are_explicit
    detected = File.join(@folder, 'ffprobe')
    FileUtils.cp(@tool, detected)
    File.chmod(0o755, detected)
    info = @settings.diagnostics('PATH' => @folder).find { |tool| tool['name'] == 'ffprobe' }
    assert_equal detected, info['active_path']
    @settings.update('ffmpeg' => @tool)
    File.unlink(@tool)
    info = @settings.diagnostics('PATH' => @folder).find { |tool| tool['name'] == 'ffmpeg' }
    assert_equal @tool, info['active_path']
    assert_equal false, info['available']
  end

  def test_invalid_updates_are_atomic_and_do_not_execute_commands
    @settings.update('ffmpeg' => @tool)
    [{ 'ffmpeg' => '/missing' }, { 'ffmpeg' => 'ffmpeg -version' }, { 'unknown' => @tool }, [], { 'ffmpeg' => 12 }].each do |body|
      assert_raises(InvasionStudio::Error) { @settings.update(body) }
    end
    File.chmod(0o644, @tool)
    assert_raises(InvasionStudio::Error) { @settings.update('ffprobe' => @tool) }
    assert_equal @tool, @settings.overrides['ffmpeg']
  end
end
