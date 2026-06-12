require 'test_helper'

class TestCommandsConcat < Minitest::Test
  def test_build_parser_sets_output_option
    options = { command: 'concat' }
    argv = ['-o', 'combined.mp4', '/tmp/clips']
    cmd = InvasionExtractor::Commands::Concat.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 'combined.mp4', options[:output]
  end

  def test_validate_exits_when_no_folder
    options = { command: 'concat' }
    argv = []
    cmd = InvasionExtractor::Commands::Concat.new(options, argv)

    error = assert_raises(SystemExit) { cmd.send(:validate!) }
    assert_equal 1, error.status
  end

  def test_validate_exits_when_invalid_folder
    options = { command: 'concat' }
    argv = ['/nonexistent']
    cmd = InvasionExtractor::Commands::Concat.new(options, argv)

    error = assert_raises(SystemExit) { cmd.send(:validate!) }
    assert_equal 1, error.status
  end

  def test_build_chapter_metadata
    options = { command: 'concat' }
    cmd = InvasionExtractor::Commands::Concat.new(options, [])

    clips = [
      '/tmp/clips/clip_a.mp4',
      '/tmp/clips/clip_b.mp4'
    ]
    metadata = {
      '/tmp/clips/clip_a.mp4' => { duration: 10.0 },
      '/tmp/clips/clip_b.mp4' => { duration: 15.5 }
    }

    result = cmd.send(:build_chapter_metadata, clips, metadata)

    assert_includes result, ";FFMETADATA1"
    assert_includes result, "title=Invasion Clips"
    assert_includes result, "[CHAPTER]"
    assert_includes result, "TIMEBASE=1/1000"
    
    # First chapter: 0 to 10000ms
    assert_includes result, "START=0"
    assert_includes result, "END=10000"
    assert_includes result, "title=clip_a.mp4"
    
    # Second chapter: 10000ms to 25500ms (10000 + 15500)
    assert_includes result, "START=10000"
    assert_includes result, "END=25500"
    assert_includes result, "title=clip_b.mp4"
  end
end
