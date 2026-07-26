require 'test_helper'
require 'tmpdir'

class TestVideoCache < Minitest::Test
  class SyntheticVideo < InvasionStudio::Video
    attr_reader :processed

    private

    def process_frames(_options)
      @processed = true
      [InvasionStudio::Frame.new(1, 'text', '00:00:00.000', path)]
    end
  end

  def test_no_cache_processes_frames_without_reading_or_writing_cache
    Dir.mktmpdir do |cache_home|
      previous_cache_home = ENV['XDG_CACHE_HOME']
      ENV['XDG_CACHE_HOME'] = cache_home
      video = SyntheticVideo.new('/missing/video.mp4', no_cache: true)

      assert_equal 1, video.frames.length
      assert video.processed
      assert_empty Dir.glob(File.join(cache_home, 'invasion-studio', '*.yml'))
    ensure
      ENV['XDG_CACHE_HOME'] = previous_cache_home
    end
  end
end
