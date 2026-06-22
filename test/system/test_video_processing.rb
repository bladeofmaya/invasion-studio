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
    video = 'test/samples/invasion-sample-720p.mp4'

    engine = nil
    bm = Benchmark.measure do
      engine = InvasionExtractor::Engine.new([video], outdir: @outdir, quiet: true, no_cache: true)
      engine.run!
    end

    log_benchmark('invasion-sample-720p', engine, bm)

    assert_equal 2, engine.clips.length,
                 "Expected 2 invasions in invasion-sample-720p.mp4"

    expected_files = ['invasion_00001.mp4', 'invasion_00002.mp4']
    actual_files = Dir.glob(File.join(@outdir, 'invasion_*.mp4')).map { |f| File.basename(f) }

    assert_equal expected_files.sort, actual_files.sort,
                 "Expected #{expected_files.inspect}, got #{actual_files.inspect}"
  end

  def test_arena_sample_720p
    video = 'test/samples/arena-sample-720p.mp4'

    engine = nil
    bm = Benchmark.measure do
      engine = InvasionExtractor::Engine.new([video], outdir: @outdir, quiet: true, no_cache: true)
      engine.run!
    end

    log_benchmark('arena-sample-720p', engine, bm)

    # Arena footage should contain 0 invasions (no invasion start/end markers)
    assert_equal 4, engine.clips.length,
                 "Expected 4 duels in arena-sample-720p.mp4"
  end
end
