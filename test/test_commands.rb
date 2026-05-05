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
    argv = ['--use-gpu', '--no-cache', '--no-progress', '--debug', '--quiet', '--benchmark', 'video.mp4']
    cmd = InvasionExtractor::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert options[:use_gpu]
    assert options[:no_cache]
    assert options[:no_progress]
    assert options[:debug]
    assert options[:quiet]
    assert options[:benchmark]
  end

  def test_build_parser_sets_float_options
    options = { command: 'extract' }
    argv = ['--pad-start', '15.5', '--pad-end', '8.0', 'video.mp4']
    cmd = InvasionExtractor::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 15.5, options[:pad_start]
    assert_equal 8.0, options[:pad_end]
  end

  def test_build_parser_sets_string_options
    options = { command: 'extract' }
    argv = [
      '--ocr-provider', 'easyocr',
      '--resume', 'session-001',
      '--save-session', 'session-002',
      '--start-pattern', 'custom-start',
      '--end-pattern', 'custom-end',
      '--profile', 'memory',
      '--benchmark-output', 'report.json',
      '--config', 'config.yml',
      'video.mp4'
    ]
    cmd = InvasionExtractor::Commands::Extract.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 'easyocr', options[:ocr_provider]
    assert_equal 'session-001', options[:resume]
    assert_equal 'session-002', options[:save_session]
    assert_equal 'custom-start', options[:start_pattern]
    assert_equal 'custom-end', options[:end_pattern]
    assert_equal 'memory', options[:profile]
    assert_equal 'report.json', options[:benchmark_output]
    assert_equal 'config.yml', options[:config]
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

class TestCommandsStatus < Minitest::Test
  def test_build_parser_sets_save_session
    options = {}
    argv = ['--save-session', 'my-session']
    cmd = InvasionExtractor::Commands::Status.new(options, argv)

    cmd.send(:parse_options!)
    assert_equal 'my-session', options[:save_session]
  end
end

class TestCommandsCache < Minitest::Test
  def test_default_cache_command_is_stats
    options = {}
    argv = []
    cmd = InvasionExtractor::Commands::Cache.new(options, argv)

    cmd.send(:parse_options!)
    assert_equal 'stats', options[:cache_command]
  end

  def test_parses_list_subcommand
    options = {}
    argv = ['list']
    cmd = InvasionExtractor::Commands::Cache.new(options, argv)

    cmd.send(:parse_options!)
    assert_equal 'list', options[:cache_command]
  end

  def test_parses_clear_subcommand
    options = {}
    argv = ['clear']
    cmd = InvasionExtractor::Commands::Cache.new(options, argv)

    cmd.send(:parse_options!)
    assert_equal 'clear', options[:cache_command]
  end
end

class TestCommandsBenchmark < Minitest::Test
  def test_build_parser_sets_options
    options = {}
    argv = [
      '--profile', 'cpu',
      '--benchmark-output', 'bench.json',
      '--ocr-provider', 'ollama',
      'video.mp4'
    ]
    cmd = InvasionExtractor::Commands::Benchmark.new(options, argv)

    cmd.send(:parse_options!)

    assert_equal 'cpu', options[:profile]
    assert_equal 'bench.json', options[:benchmark_output]
    assert_equal 'ollama', options[:ocr_provider]
  end

  def test_validate_exits_when_no_video_files
    options = {}
    argv = []
    cmd = InvasionExtractor::Commands::Benchmark.new(options, argv)

    error = assert_raises(SystemExit) { cmd.send(:validate!) }
    assert_equal 1, error.status
  end

  def test_validate_exits_when_no_valid_video_files
    options = {}
    argv = ['/nonexistent/video.mp4']
    cmd = InvasionExtractor::Commands::Benchmark.new(options, argv)

    error = assert_raises(SystemExit) { cmd.send(:validate!) }
    assert_equal 1, error.status
  end
end
