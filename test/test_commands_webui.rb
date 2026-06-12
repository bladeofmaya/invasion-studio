require 'test_helper'

class TestCommandsWebui < Minitest::Test
  def test_build_parser_sets_port
    options = { command: 'webui' }
    argv = ['-p', '8080', '/tmp/clips']
    cmd = InvasionExtractor::Commands::Webui.new(options, argv)
    cmd.send(:parse_options!)

    assert_equal 8080, options[:port]
  end

  def test_validate_exits_when_no_folder
    options = { command: 'webui' }
    argv = []
    cmd = InvasionExtractor::Commands::Webui.new(options, argv)

    error = assert_raises(SystemExit) { cmd.send(:validate!) }
    assert_equal 1, error.status
  end

  def test_validate_exits_when_invalid_folder
    options = { command: 'webui' }
    argv = ['/nonexistent/folder']
    cmd = InvasionExtractor::Commands::Webui.new(options, argv)

    error = assert_raises(SystemExit) { cmd.send(:validate!) }
    assert_equal 1, error.status
  end

  def test_validate_allows_valid_folder
    require 'tmpdir'
    options = { command: 'webui' }
    dir = Dir.mktmpdir
    argv = [dir]
    cmd = InvasionExtractor::Commands::Webui.new(options, argv)

    # Should not raise
    cmd.send(:validate!)
  ensure
    FileUtils.rm_rf(dir) if defined?(dir)
  end
end
