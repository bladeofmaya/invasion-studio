require_relative 'test_helper'
require 'fileutils'

class TestVideoProcessing < Minitest::Test
  include SystemTestHelper

  def setup
    @outdir = 'tmp/system_test_clips'
    FileUtils.rm_rf(@outdir)
    FileUtils.mkdir_p(@outdir)
  end

  def teardown
    FileUtils.rm_rf(@outdir)
    FileUtils.rm_rf('invasion_clips')
  end

  def test_invasion_sample_720p
    fixture = TestSupport::SystemFixtures::INVASION

    engine = nil
    bm = Benchmark.measure do
      engine = InvasionStudio::Engine.new(
        [fixture.path],
        outdir: @outdir,
        quiet: true,
        no_cache: true,
        ocr_batch_size: ocr_batch_size
      )
      engine.run!
    end

    log_benchmark(fixture, engine, bm)

    assert_equal fixture.expected_segments, engine.clips.length,
                 "Expected #{fixture.expected_segments} invasions in #{File.basename(fixture.path)}"

    expected_files = fixture.expected_segments.times.map { |index| format('invasion_%05d.mp4', index + 1) }
    actual_files = Dir.glob(File.join(@outdir, 'invasion_*.mp4')).map { |f| File.basename(f) }

    assert_equal expected_files.sort, actual_files.sort,
                 "Expected #{expected_files.inspect}, got #{actual_files.inspect}"
  end

  def test_arena_sample_720p
    fixture = TestSupport::SystemFixtures::ARENA

    engine = nil
    bm = Benchmark.measure do
      engine = InvasionStudio::Engine.new(
        [fixture.path],
        outdir: @outdir,
        quiet: true,
        no_cache: true,
        ocr_batch_size: ocr_batch_size,
        command: fixture.mode.to_s
      )
      engine.run!
    end

    log_benchmark(fixture, engine, bm)

    assert_equal fixture.expected_segments, engine.clips.length,
                 "Expected #{fixture.expected_segments} arena encounters in #{File.basename(fixture.path)}"
    assert_empty Dir.glob(File.join(@outdir, '*.mp4')), 'Scan-only fixture should not generate clips'
  end
end
