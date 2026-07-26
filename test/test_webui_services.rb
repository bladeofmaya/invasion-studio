require 'test_helper'
require 'stringio'

class TestWebuiServices < Minitest::Test
  class OutputRunner < TestSupport::FakeProcessRunner
    def run(*command, **options)
      super
      File.write(command.last, 'preview') if @success
      @success
    end
  end

  def test_json_request_parses_objects_and_rejects_invalid_json
    parser = InvasionStudio::Webui::JsonRequest.new

    assert_equal({ 'name' => 'Group' }, parser.parse(StringIO.new('{"name":"Group"}')))
    assert_raises(InvasionStudio::Webui::InvalidJsonRequest) do
      parser.parse(StringIO.new('{'))
    end
  end

  def test_error_mapper_maps_known_and_unknown_errors
    mapper = InvasionStudio::Webui::ErrorMapper.new

    assert_equal [404, { error: 'missing' }], mapper.map(InvasionStudio::Webui::NotFoundError.new('missing'))
    assert_equal [400, { error: 'bad input' }], mapper.map(InvasionStudio::Webui::ValidationError.new('bad input'))
    assert_equal [409, { error: 'duplicate' }], mapper.map(InvasionStudio::Webui::ConflictError.new('duplicate'))
    assert_equal [422, { error: 'failed' }], mapper.map(InvasionStudio::Webui::ProcessingError.new('failed'))
    assert_equal [500, { error: 'boom' }], mapper.map(StandardError.new('boom'))
  end

  def test_file_opener_selects_platform_command_without_a_shell
    linux_runner = TestSupport::FakeProcessRunner.new
    mac_runner = TestSupport::FakeProcessRunner.new

    assert InvasionStudio::Webui::FileOpener.new(process_runner: linux_runner, platform: 'linux').open('/tmp/a file.mp4')
    assert InvasionStudio::Webui::FileOpener.new(process_runner: mac_runner, platform: 'darwin').open('/tmp/a file.mp4')
    assert_equal ['xdg-open', '/tmp/a file.mp4'], linux_runner.commands.first[:command]
    assert_equal ['open', '/tmp/a file.mp4'], mac_runner.commands.first[:command]
  end

  def test_preview_remuxer_builds_and_reuses_mtime_cache
    Dir.mktmpdir do |directory|
      source = File.join(directory, 'clip.mp4')
      File.write(source, 'video')
      runner = OutputRunner.new
      remuxer = InvasionStudio::Webui::PreviewRemuxer.new(directory, process_runner: runner)

      first = remuxer.remux(source, 2)
      second = remuxer.remux(source, 2)

      assert_equal first, second
      assert_equal 1, runner.commands.length
      assert_includes runner.commands.first[:command], '0:a:1'
      assert_equal 'preview', File.read(first)
    end
  end

  def test_preview_remuxer_removes_failed_output
    Dir.mktmpdir do |directory|
      source = File.join(directory, 'clip.mp4')
      File.write(source, 'video')
      remuxer = InvasionStudio::Webui::PreviewRemuxer.new(
        directory, process_runner: TestSupport::FakeProcessRunner.new(success: false)
      )

      assert_nil remuxer.remux(source, 1)
      assert_equal [], Dir.glob(File.join(directory, '.preview_tmp', '*'))
    end
  end
end
