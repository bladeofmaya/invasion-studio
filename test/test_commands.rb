require 'test_helper'

class TestCommandsBase < Minitest::Test
  def test_base_command_raises_not_implemented_error
    base = InvasionExtractor::Commands::Base.new({}, [])
    assert_raises(NotImplementedError) { base.run }
  end

  def test_base_command_stores_options_and_argv
    options = { foo: 'bar' }
    argv = ['video.mp4']
    base = InvasionExtractor::Commands::Base.new(options, argv)

    assert_equal options, base.options
    assert_equal argv, base.argv
  end
end

class TestCommandsExtract < Minitest::Test
  def test_build_parser_sets_options
    options = { command: 'extract' }
    argv = ['-p', 'test-prefix', '-o', 'test-outdir', '--fps', '5', 'video.mp4']
    cmd = InvasionExtractor::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 'test-prefix', options[:prefix]
    assert_equal 'test-outdir', options[:outdir]
    assert_equal 5, options[:fps]
  end

  def test_build_parser_sets_boolean_flags
    options = { command: 'extract' }
    argv = ['--no-cache', '--debug', '--quiet', '--continue-on-error', 'video.mp4']
    cmd = InvasionExtractor::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert options[:no_cache]
    assert options[:debug]
    assert options[:quiet]
    assert options[:continue_on_error]
  end

  def test_build_parser_sets_float_options
    options = { command: 'extract' }
    argv = ['--pad-start', '15.5', '--pad-end', '8.0', 'video.mp4']
    cmd = InvasionExtractor::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 15.5, options[:pad_start]
    assert_equal 8.0, options[:pad_end]
  end

  def test_build_parser_sets_ffmpeg_threads
    options = { command: 'extract' }
    argv = ['--ffmpeg-threads', '12', 'video.mp4']
    cmd = InvasionExtractor::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 12, options[:ffmpeg_threads]
  end

  def test_validate_exits_when_no_video_files
    options = { command: 'extract' }
    argv = []
    cmd = InvasionExtractor::Commands::Extract.new(options, argv)

    error = assert_raises(SystemExit) { cmd.send(:validate!) }
    assert_equal 1, error.status
  end

  def test_validate_exits_when_no_valid_video_files
    options = { command: 'extract' }
    argv = ['/nonexistent/video.mp4']
    cmd = InvasionExtractor::Commands::Extract.new(options, argv)

    error = assert_raises(SystemExit) { cmd.send(:validate!) }
    assert_equal 1, error.status
  end

  def test_video_files_returns_existing_files
    options = { command: 'extract' }
    argv = ['test/samples/invasion-sample-720p.mp4', '/nonexistent.mp4']
    cmd = InvasionExtractor::Commands::Extract.new(options, argv)

    files = cmd.send(:video_files)
    assert_equal ['test/samples/invasion-sample-720p.mp4'], files
  end

  def test_scan_command_uses_extract_class
    options = { command: 'scan' }
    argv = ['test/samples/invasion-sample-720p.mp4']
    cmd = InvasionExtractor::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)
    assert_equal 'scan', options[:command]
  end
end

class TestCommandsExportKdenlive < Minitest::Test
  def test_build_parser_sets_output_option
    options = { command: 'export-kdenlive' }
    argv = ['-o', 'test.kdenlive', '/tmp/clips']
    cmd = InvasionExtractor::Commands::ExportKdenlive.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 'test.kdenlive', options[:output]
  end

  def test_build_parser_sets_transition_duration
    options = { command: 'export-kdenlive' }
    argv = ['-t', '3.5', '/tmp/clips']
    cmd = InvasionExtractor::Commands::ExportKdenlive.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 3.5, options[:transition_duration]
  end

  def test_validate_exits_when_no_folder
    options = { command: 'export-kdenlive' }
    argv = []
    cmd = InvasionExtractor::Commands::ExportKdenlive.new(options, argv)

    error = assert_raises(SystemExit) { cmd.send(:validate!) }
    assert_equal 1, error.status
  end

  def test_validate_exits_when_invalid_folder
    options = { command: 'export-kdenlive' }
    argv = ['/nonexistent/folder']
    cmd = InvasionExtractor::Commands::ExportKdenlive.new(options, argv)

    error = assert_raises(SystemExit) { cmd.send(:validate!) }
    assert_equal 1, error.status
  end
end
