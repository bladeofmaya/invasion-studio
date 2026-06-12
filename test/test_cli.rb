require 'test_helper'

class TestCLI < Minitest::Test
  def test_default_command_is_extract
    cli = InvasionExtractor::CLI.new(['video.mp4'])
    cli.send(:parse_global_options!)
    cli.send(:detect_command!)
    assert_equal 'extract', cli.options[:command]
  end

  def test_parses_debug_flag
    cli = InvasionExtractor::CLI.new(['--debug', 'video.mp4'])
    cli.send(:parse_global_options!)
    assert cli.options[:debug]
  end

  def test_parses_quiet_flag
    cli = InvasionExtractor::CLI.new(['--quiet', 'video.mp4'])
    cli.send(:parse_global_options!)
    assert cli.options[:quiet]
  end

  def test_detects_extract_command
    cli = InvasionExtractor::CLI.new(['extract', 'video.mp4'])
    cli.send(:parse_global_options!)
    cli.send(:detect_command!)
    assert_equal 'extract', cli.options[:command]
  end

  def test_detects_scan_command
    cli = InvasionExtractor::CLI.new(['scan', 'video.mp4'])
    cli.send(:parse_global_options!)
    cli.send(:detect_command!)
    assert_equal 'scan', cli.options[:command]
  end

  def test_non_command_argument_preserved_for_default
    cli = InvasionExtractor::CLI.new(['video.mp4'])
    cli.send(:parse_global_options!)
    cli.send(:detect_command!)

    assert_equal 'extract', cli.options[:command]
    assert_equal ['video.mp4'], cli.send(:instance_variable_get, :@argv)
  end

  def test_version_flag_prints_version_and_exits
    stdout, _stderr = capture_io do
      cli = InvasionExtractor::CLI.new(['--version'])
      error = assert_raises(SystemExit) { cli.send(:parse_global_options!) }
      assert_equal 0, error.status
    end

    assert_includes stdout, InvasionExtractor::VERSION
  end

  def test_help_flag_prints_usage_and_exits
    stdout, _stderr = capture_io do
      cli = InvasionExtractor::CLI.new(['--help'])
      error = assert_raises(SystemExit) { cli.send(:parse_global_options!) }
      assert_equal 0, error.status
    end

    assert_includes stdout, "Invasion Extractor"
    assert_includes stdout, "Usage:"
  end

  def test_command_class_for_extract
    cli = InvasionExtractor::CLI.new([])
    assert_equal InvasionExtractor::Commands::Extract, cli.send(:command_class_for, 'extract')
  end

  def test_command_class_for_scan
    cli = InvasionExtractor::CLI.new([])
    assert_equal InvasionExtractor::Commands::Extract, cli.send(:command_class_for, 'scan')
  end

  def test_command_class_for_export_kdenlive
    cli = InvasionExtractor::CLI.new([])
    assert_equal InvasionExtractor::Commands::ExportKdenlive, cli.send(:command_class_for, 'export-kdenlive')
  end

  def test_command_class_for_webui
    cli = InvasionExtractor::CLI.new([])
    assert_equal InvasionExtractor::Commands::Webui, cli.send(:command_class_for, 'webui')
  end

  def test_detects_export_kdenlive_command
    cli = InvasionExtractor::CLI.new(['export-kdenlive', '/tmp/clips'])
    cli.send(:parse_global_options!)
    cli.send(:detect_command!)
    assert_equal 'export-kdenlive', cli.options[:command]
  end

  def test_detects_webui_command
    cli = InvasionExtractor::CLI.new(['webui', '/tmp/clips'])
    cli.send(:parse_global_options!)
    cli.send(:detect_command!)
    assert_equal 'webui', cli.options[:command]
  end

  def test_default_options_are_frozen
    assert InvasionExtractor::CLI::DEFAULT_OPTIONS.frozen?
  end

  def test_options_are_independent_per_instance
    cli1 = InvasionExtractor::CLI.new(['--debug', 'video.mp4'])
    cli1.send(:parse_global_options!)

    cli2 = InvasionExtractor::CLI.new(['video.mp4'])
    cli2.send(:parse_global_options!)

    assert cli1.options[:debug]
    refute cli2.options[:debug]
  end

  def test_parses_ffmpeg_threads_flag
    cli = InvasionExtractor::CLI.new(['--ffmpeg-threads', '8', 'video.mp4'])
    cli.send(:parse_global_options!)
    assert_equal 8, cli.options[:ffmpeg_threads]
  end

  def test_default_ffmpeg_threads_is_4
    cli = InvasionExtractor::CLI.new(['video.mp4'])
    cli.send(:parse_global_options!)
    assert_equal 4, cli.options[:ffmpeg_threads]
  end
end
