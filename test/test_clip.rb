require 'test_helper'
require 'tmpdir'

class TestClip < Minitest::Test
  def test_write_does_not_leave_an_ffmpeg_log_beside_the_clip
    Dir.mktmpdir do |directory|
      output = File.join(directory, 'invasion_00001.mp4')
      writer = Object.new
      captured_log_path = nil
      writer.define_singleton_method(:write) do |_segment, output_path, log_path|
        captured_log_path = log_path
        File.write(output_path, 'clip')
        File.write(log_path, 'ffmpeg output')
        true
      end
      clip = InvasionStudio::Clip.new(
        InvasionStudio::Scanner::Segment.new('00:00:20', 'a.mp4', '00:00:30', 'a.mp4'),
        clip_writer: writer
      )

      clip.write(output)

      assert_equal output, clip.generated_file
      refute File.exist?(File.join(directory, '.invasion_00001_ffmpeg.log'))
      refute File.exist?(captured_log_path)
      refute_equal directory, File.dirname(captured_log_path)
    end
  end

  def test_does_not_mutate_scanner_segment
    segment = InvasionStudio::Scanner::Segment.new('00:00:20', 'a.mp4', '00:00:30', 'a.mp4')

    first = InvasionStudio::Clip.new(segment)
    second = InvasionStudio::Clip.new(segment)

    assert_equal '00:00:20', segment.start_time
    assert_equal first.segment.start_time, second.segment.start_time
  end

  def test_engine_reuses_constructed_clips
    segment = InvasionStudio::Scanner::Segment.new('00:00:20', 'a.mp4', '00:00:30', 'a.mp4')
    scanner = Struct.new(:invasion_segments).new([segment])
    engine = InvasionStudio::Engine.new([])
    engine.instance_variable_set(:@scanner, scanner)

    assert_same engine.clips, engine.clips
  end
end
