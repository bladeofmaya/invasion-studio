require 'test_helper'

class TestOCRComponents < Minitest::Test
  def test_metadata_probe_parses_video_and_audio_streams
    runner = TestSupport::FakeProcessRunner.new(stdout: JSON.generate({ streams: [
      { codec_type: 'video', height: 720, width: 1280, r_frame_rate: '30000/1001', duration: '12.5', codec_name: 'h264' },
      { codec_type: 'audio', codec_name: 'aac' }
    ] }))

    metadata = InvasionStudio::OCR::VideoMetadataProbe.new(process_runner: runner).call('video.mp4')

    assert_equal 720, metadata[:height]
    assert_in_delta 29.97, metadata[:fps], 0.001
    assert_equal 1, metadata[:audio_stream_count]
    assert_in_delta 12.5, metadata[:duration], 0.001
    assert_equal 'h264', metadata[:video_codec]
    assert_equal 'aac', metadata[:audio_codec]
  end

  def test_metadata_probe_falls_back_to_container_duration
    runner = TestSupport::FakeProcessRunner.new(stdout: JSON.generate({
      streams: [{ codec_type: 'video', height: 1080, width: 1920, r_frame_rate: '60/1', codec_name: 'h264' }],
      format: { duration: '321.7' }
    }))

    metadata = InvasionStudio::OCR::VideoMetadataProbe.new(process_runner: runner).call('video.mkv')

    assert_in_delta 321.7, metadata[:duration], 0.001
  end

  def test_crop_geometry_scales_and_keeps_even_dimensions
    crop = InvasionStudio::OCR::CropGeometry.new.call(height: 720)

    assert_equal({ width: 350, height: 64, x: 474, y: 480 }, crop)
  end

  def test_frame_extractor_builds_ffmpeg_command
    runner = TestSupport::FakeProcessRunner.new
    extractor = InvasionStudio::OCR::FrameExtractor.new(process_runner: runner)

    thread = extractor.start(
      video_path: 'video with spaces.mp4',
      frames_dir: '/tmp/frames',
      fps: 2,
      crop: { width: 350, height: 64, x: 474, y: 480 },
      options: { ffmpeg_threads: 3 }
    )
    assert thread.value

    command = runner.commands.fetch(0)
    input_index = command[:command].index('-i')
    assert_equal 'video with spaces.mp4', command[:command][input_index + 1]
    assert_includes command[:command], 'fps=2,crop=350:64:474:480'
    assert_equal File::NULL, command[:options][:log_path]
  end

  def test_progress_reporter_is_monotonic
    updates = []
    reporter = InvasionStudio::OCR::ProgressReporter.new(
      total: 2,
      callback: ->(current, total) { updates << [current, total] }
    )

    reporter.advance
    reporter.advance

    assert_equal [[1, 2], [2, 2]], updates
  end
end
