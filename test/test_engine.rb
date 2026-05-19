require 'test_helper'

class TestEngine < Minitest::Test
  def setup
    @outdir = 'tmp/invasion_clips'
    FileUtils.rm_rf(@outdir)
    FileUtils.mkdir_p(@outdir)
  end

  def teardown
    FileUtils.rm_rf(@outdir)
    FileUtils.rm_rf('invasion_clips')
  end

  def test_engine_system
    engine = InvasionExtractor::Engine.new(
      ['test/samples/invasion-sample-720p.mp4'],
      { outdir: @outdir }
    )

    assert_instance_of InvasionExtractor::Engine, engine
    assert_instance_of Array, engine.videos
    assert_instance_of InvasionExtractor::Video, engine.videos.first
    assert_equal 1, engine.videos.size

    engine.run!

    clips = engine.clips
    assert_instance_of Array, clips
    assert clips.length > 0, "Expected at least one clip to be generated"

    expected_files = ['invasion_00001.mp4', 'invasion_00002.mp4']
    actual_files = Dir.glob(File.join(@outdir, 'invasion_*.mp4')).map { |f| File.basename(f) }

    assert_equal expected_files.sort, actual_files.sort,
                 "Expected files #{expected_files.inspect} in #{@outdir}, but found #{actual_files.inspect}"
  end
end
