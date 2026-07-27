require 'test_helper'

class TestCommandsBase < Minitest::Test
  def test_base_command_raises_not_implemented_error
    base = InvasionStudio::Commands::Base.new({}, [])
    assert_raises(NotImplementedError) { base.run }
  end

  def test_base_command_stores_options_and_argv
    options = { foo: 'bar' }
    argv = ['video.mp4']
    base = InvasionStudio::Commands::Base.new(options, argv)

    assert_equal options, base.options
    assert_equal argv, base.argv
  end
end

class TestCommandsExtract < Minitest::Test
  def test_build_parser_sets_options
    options = { command: 'extract' }
    argv = ['-p', 'test-prefix', '-o', 'test-outdir', '--fps', '5', 'video.mp4']
    cmd = InvasionStudio::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 'test-prefix', options[:prefix]
    assert_equal 'test-outdir', options[:outdir]
    assert_equal 5, options[:fps]
  end

  def test_build_parser_sets_boolean_flags
    options = { command: 'extract' }
    argv = ['--no-cache', '--debug', '--quiet', '--continue-on-error', 'video.mp4']
    cmd = InvasionStudio::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert options[:no_cache]
    assert options[:debug]
    assert options[:quiet]
    assert options[:continue_on_error]
  end

  def test_build_parser_sets_float_options
    options = { command: 'extract' }
    argv = ['--pad-start', '15.5', '--pad-end', '8.0', 'video.mp4']
    cmd = InvasionStudio::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 15.5, options[:pad_start]
    assert_equal 8.0, options[:pad_end]
  end

  def test_build_parser_sets_ffmpeg_threads
    options = { command: 'extract' }
    argv = ['--ffmpeg-threads', '12', 'video.mp4']
    cmd = InvasionStudio::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 12, options[:ffmpeg_threads]
  end

  def test_build_parser_sets_ocr_workers
    options = { command: 'extract' }
    argv = ['--ocr-workers', '3', 'video.mp4']
    cmd = InvasionStudio::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 3, options[:ocr_workers]
  end

  def test_build_parser_sets_ocr_batch_size
    options = { command: 'extract' }
    argv = ['--ocr-batch-size', '8', 'video.mp4']
    cmd = InvasionStudio::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 8, options[:ocr_batch_size]
  end

  def test_validate_rejects_project_combined_with_explicit_outdir
    options = InvasionStudio::CLI::DEFAULT_OPTIONS.dup
    cmd = InvasionStudio::Commands::Extract.new(options, ['--project', 'proj', '-o', 'out', __FILE__])
    cmd.send(:parse_options!)

    error = assert_raises(InvasionStudio::Error) { cmd.send(:validate!) }

    assert_equal '--project cannot be combined with --outdir or --prefix', error.message
  end

  def test_validate_project_accepts_default_filled_options
    # The CLI pre-fills :outdir/:prefix defaults; --project alone must not
    # trip the exclusivity check.
    options = InvasionStudio::CLI::DEFAULT_OPTIONS.dup
    cmd = InvasionStudio::Commands::Extract.new(options, ['--project', 'proj', __FILE__])
    cmd.send(:parse_options!)

    cmd.send(:validate!)

    assert_equal File.join('proj', 'clips'), options[:outdir]
    assert_equal 'clip', options[:prefix]
  end

  def test_validate_rejects_non_positive_ocr_workers
    options = { command: 'extract', ocr_workers: 0 }
    cmd = InvasionStudio::Commands::Extract.new(options, [__FILE__])

    error = assert_raises(InvasionStudio::Error) { cmd.send(:validate!) }

    assert_equal '--ocr-workers must be greater than zero', error.message
  end

  def test_validate_rejects_non_positive_ocr_batch_size
    options = { command: 'extract', ocr_batch_size: 0 }
    cmd = InvasionStudio::Commands::Extract.new(options, [__FILE__])

    error = assert_raises(InvasionStudio::Error) { cmd.send(:validate!) }

    assert_equal '--ocr-batch-size must be greater than zero', error.message
  end

  def test_validate_exits_when_no_video_files
    options = { command: 'extract' }
    argv = []
    cmd = InvasionStudio::Commands::Extract.new(options, argv)

    stdout, = capture_io do
      error = assert_raises(SystemExit) { cmd.send(:validate!) }
      assert_equal 1, error.status
    end
    assert_includes stdout, 'No video files specified'
  end

  def test_validate_exits_when_no_valid_video_files
    options = { command: 'extract' }
    argv = ['/nonexistent/video.mp4']
    cmd = InvasionStudio::Commands::Extract.new(options, argv)

    stdout, = capture_io do
      error = assert_raises(SystemExit) { cmd.send(:validate!) }
      assert_equal 1, error.status
    end
    assert_includes stdout, 'No valid video files found'
  end

  def test_video_files_returns_existing_files
    options = { command: 'extract' }
    argv = [__FILE__, '/nonexistent.mp4']
    cmd = InvasionStudio::Commands::Extract.new(options, argv)

    files = cmd.send(:video_files)
    assert_equal [__FILE__], files
  end

  def test_scan_command_uses_extract_class
    options = { command: 'scan' }
    argv = ['video.mp4']
    cmd = InvasionStudio::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)
    assert_equal 'scan', options[:command]
  end
end

class TestCommandsExportKdenlive < Minitest::Test
  def test_build_parser_sets_output_option
    options = { command: 'export-kdenlive' }
    argv = ['-o', 'test.kdenlive', '/tmp/clips']
    cmd = InvasionStudio::Commands::ExportKdenlive.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 'test.kdenlive', options[:output]
  end

  def test_validate_exits_when_no_folder
    options = { command: 'export-kdenlive' }
    argv = []
    cmd = InvasionStudio::Commands::ExportKdenlive.new(options, argv)

    stdout, = capture_io do
      error = assert_raises(SystemExit) { cmd.send(:validate!) }
      assert_equal 1, error.status
    end
    assert_includes stdout, 'No folder specified'
  end

  def test_validate_exits_when_invalid_folder
    options = { command: 'export-kdenlive' }
    argv = ['/nonexistent/folder']
    cmd = InvasionStudio::Commands::ExportKdenlive.new(options, argv)

    stdout, = capture_io do
      error = assert_raises(SystemExit) { cmd.send(:validate!) }
      assert_equal 1, error.status
    end
    assert_includes stdout, 'is not a valid directory'
  end
end
