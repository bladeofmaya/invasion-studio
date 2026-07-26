require 'test_helper'

class TestClipFinalizer < Minitest::Test
  class OutputWritingRunner
    attr_reader :commands

    def initialize
      @commands = []
    end

    def run(*command)
      @commands << command
      File.write(command.last, 'media output')
      true
    end
  end

  def setup
    @directory = Dir.mktmpdir
    @source = File.join(@directory, 'fight.mp4')
    File.write(@source, 'original')
    @clip = {
      'id' => 'fight', 'filename' => 'fight.mp4', 'path' => 'fight.mp4',
      'cuts' => [{ 'start' => 2.0, 'end' => 4.0 }]
    }
    @catalog = InvasionStudio::ClipCatalog.new(@directory, [@clip])
  end

  def teardown
    FileUtils.rm_rf(@directory)
  end

  def test_finalize_backs_up_replaces_source_and_clears_cuts
    finalizer = build_finalizer(duration: 10.0)
    captured = nil
    media_operation = lambda do |backup, segments, output|
      captured = [backup, segments]
      File.write(output, 'edited')
      true
    end

    assert finalizer.finalize(@clip, media_operation: media_operation)
    assert_equal [{ start: 0.0, end: 2.0 }, { start: 4.0, end: 10.0 }], captured.last
    assert_equal 'original', File.read(captured.first)
    assert_equal 'edited', File.read(@source)
    assert_equal [], @clip['cuts']
  end

  def test_finalize_rejects_missing_cuts_metadata_or_complete_removal
    @clip['cuts'] = []
    refute build_finalizer(duration: 10.0).finalize(@clip)

    @clip['cuts'] = [{ 'start' => 1.0, 'end' => 2.0 }]
    refute build_finalizer(metadata: nil).finalize(@clip)

    @clip['cuts'] = [{ 'start' => 0.0, 'end' => 10.0 }]
    refute build_finalizer(duration: 10.0).finalize(@clip)
  end

  def test_failed_media_operation_preserves_source_and_cuts
    finalizer = build_finalizer(duration: 10.0)

    refute finalizer.finalize(@clip, media_operation: ->(*_args) { false })
    assert_equal 'original', File.read(@source)
    assert_equal [{ 'start' => 2.0, 'end' => 4.0 }], @clip['cuts']
  end

  def test_default_media_operation_uses_injected_process_runner
    runner = TestSupport::FakeProcessRunner.new(success: false)
    finalizer = build_finalizer(duration: 10.0, process_runner: runner)

    refute finalizer.finalize(@clip)
    command = runner.commands.fetch(0)[:command]
    assert_equal 'ffmpeg', command.first
    assert_includes command, '-ss'
    assert_includes command, '-map'
  end

  def test_default_media_operation_cuts_and_concatenates_multiple_segments
    runner = OutputWritingRunner.new
    finalizer = build_finalizer(duration: 10.0, process_runner: runner)

    assert finalizer.finalize(@clip)
    assert_equal 3, runner.commands.length
    assert_equal %w[ffmpeg ffmpeg ffmpeg], runner.commands.map(&:first)
    assert_includes runner.commands.last, 'concat'
    assert_equal 'media output', File.read(@source)
  end

  private

  def build_finalizer(duration: nil, metadata: :duration, process_runner: TestSupport::FakeProcessRunner.new)
    resolved_metadata = metadata == :duration ? { duration: duration } : metadata
    InvasionStudio::ClipFinalizer.new(
      @directory,
      @catalog,
      process_runner: process_runner,
      metadata_probe: ->(_path) { resolved_metadata },
      clock: -> { Time.at(123) },
      random_suffix: -> { 'abcd' }
    )
  end
end
