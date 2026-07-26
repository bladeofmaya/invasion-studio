require 'test_helper'
require 'tmpdir'

class TestClipWriter < Minitest::Test
  def setup
    @runner = TestSupport::FakeProcessRunner.new
    @writer = InvasionStudio::ClipWriter.new(process_runner: @runner)
  end

  def test_single_file_writer_builds_one_copy_command
    segment = InvasionStudio::Scanner::Segment.new('00:00:02', 'a.mp4', '00:00:09', 'a.mp4')

    assert @writer.write(segment, '/tmp/output.mp4', '/tmp/output.log')

    command = @runner.commands.fetch(0)
    assert_equal ['ffmpeg', '-i', 'a.mp4', '-ss', '00:00:02', '-to', '00:00:09',
                  '-map', '0', '-c', 'copy', '-y', '/tmp/output.mp4'], command[:command]
    assert_equal '/tmp/output.log', command[:options][:log_path]
  end

  def test_multi_file_writer_runs_two_cuts_and_concat
    segment = InvasionStudio::Scanner::Segment.new('00:00:02', 'a.mp4', '00:00:09', 'b.mp4')

    assert @writer.write(segment, '/tmp/output.mp4', '/tmp/output.log')

    assert_equal 3, @runner.commands.length
    assert_includes @runner.commands.fetch(0)[:command], 'a.mp4'
    assert_includes @runner.commands.fetch(1)[:command], 'b.mp4'
    assert_equal 'concat', @runner.commands.fetch(2)[:command][2]
  end
end
