require 'test_helper'

class TestCommandsWebui < Minitest::Test
  def test_build_parser_sets_port
    options = { command: 'webui' }
    argv = ['-p', '8080', '/tmp/clips']
    cmd = InvasionStudio::Commands::Webui.new(options, argv)
    cmd.send(:parse_options!)

    assert_equal 8080, options[:port]
  end

  def test_validate_allows_ephemeral_port
    options = { command: 'webui' }
    dir = Dir.mktmpdir
    cmd = InvasionStudio::Commands::Webui.new(options, ['--port', '0', dir])

    cmd.send(:parse_options!)
    cmd.send(:validate!)

    assert_equal 0, options[:port]
  ensure
    FileUtils.rm_rf(dir) if defined?(dir)
  end

  def test_build_parser_sets_parent_pid
    options = { command: 'webui' }
    cmd = InvasionStudio::Commands::Webui.new(options, ['--parent-pid', '1234', '/tmp/clips'])

    cmd.send(:parse_options!)

    assert_equal 1234, options[:parent_pid]
  end

  def test_validate_exits_when_no_folder
    options = { command: 'webui' }
    argv = []
    cmd = InvasionStudio::Commands::Webui.new(options, argv)

    stdout, = capture_io do
      error = assert_raises(SystemExit) { cmd.send(:validate!) }
      assert_equal 1, error.status
    end
    assert_includes stdout, 'No folder specified'
  end

  def test_validate_exits_when_invalid_folder
    options = { command: 'webui' }
    argv = ['/nonexistent/folder']
    cmd = InvasionStudio::Commands::Webui.new(options, argv)

    stdout, = capture_io do
      error = assert_raises(SystemExit) { cmd.send(:validate!) }
      assert_equal 1, error.status
    end
    assert_includes stdout, 'is not a valid directory'
  end

  def test_validate_allows_valid_folder
    require 'tmpdir'
    options = { command: 'webui' }
    dir = Dir.mktmpdir
    argv = [dir]
    cmd = InvasionStudio::Commands::Webui.new(options, argv)

    # Should not raise
    cmd.send(:validate!)
  ensure
    FileUtils.rm_rf(dir) if defined?(dir)
  end
end
