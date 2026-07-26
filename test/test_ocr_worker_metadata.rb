require 'test_helper'

class TestOCRWorkerMetadata < Minitest::Test
  def test_parses_fractional_metadata_through_injected_process_runner
    runner = TestSupport::FakeProcessRunner.new(stdout: JSON.generate({
      streams: [{ height: 1440, width: 2560, r_frame_rate: '30000/1001', duration: '12.5' }]
    }))

    worker = InvasionStudio::OCRWorker.new('video with spaces.mp4', nil, process_runner: runner)

    assert_in_delta 29.970, worker.video_metadata[:fps], 0.001
    assert_equal 12.5, worker.video_metadata[:duration]
    assert_equal 'video with spaces.mp4', runner.commands.fetch(0)[:command].last
  end

  def test_failed_metadata_probe_is_characterized_as_nil
    runner = TestSupport::FakeProcessRunner.new(success: false, stderr: 'probe failed')

    worker = InvasionStudio::OCRWorker.new('missing.mp4', nil, process_runner: runner)

    assert_nil worker.video_metadata
  end
end
