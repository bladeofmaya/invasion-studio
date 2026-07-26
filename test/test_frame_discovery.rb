require 'test_helper'
require 'tmpdir'

class TestFrameDiscovery < Minitest::Test
  FinishedProducer = Struct.new(:alive?)

  def test_yields_sequential_frames_once_and_reports_shared_progress
    Dir.mktmpdir do |directory|
      3.times { |index| File.write(File.join(directory, format('frame_%06d.jpg', index + 1)), '') }
      progress = []
      paths = []

      InvasionStudio::OCR::FrameDiscovery.new.each(
        directory,
        producer: FinishedProducer.new(false),
        total: 3,
        progress: ->(current, total) { progress << [current, total] }
      ) { |path| paths << File.basename(path) }

      assert_equal %w[frame_000001.jpg frame_000002.jpg frame_000003.jpg], paths
      assert_equal [[1, 3], [2, 3], [3, 3]], progress
    end
  end

  def test_waits_for_the_next_frame_while_producer_is_alive
    Dir.mktmpdir do |directory|
      producer_states = [true, false]
      producer = Object.new
      producer.define_singleton_method(:alive?) { producer_states.shift || false }
      sleeper = lambda do |_interval|
        File.write(File.join(directory, 'frame_000001.jpg'), '')
      end
      paths = []

      discovery = InvasionStudio::OCR::FrameDiscovery.new(sleeper: sleeper)
      discovery.each(directory, producer: producer) { |path| paths << File.basename(path) }

      assert_equal ['frame_000001.jpg'], paths
    end
  end
end
