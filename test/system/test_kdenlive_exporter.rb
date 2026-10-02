require 'test_helper'

class TestKdenliveExporter < Minitest::Test
  def setup
    @folder = '/tmp/test_clips'
    FileUtils.mkdir_p(@folder)

    # Create a real small video for splicing
    system("ffmpeg -f lavfi -i testsrc=duration=2:size=320x240:rate=30 -f lavfi -i sine=frequency=1000:duration=2 -pix_fmt yuv420p -c:v libx264 -c:a aac -y #{@folder}/clip_a.mp4 2>/dev/null")
    system("ffmpeg -f lavfi -i testsrc=duration=3:size=320x240:rate=30 -f lavfi -i sine=frequency=1000:duration=3 -pix_fmt yuv420p -c:v libx264 -c:a aac -y #{@folder}/clip_b.mp4 2>/dev/null")
  end

  def teardown
    FileUtils.rm_rf(@folder)
  end

  def test_run_creates_kdenlive_file_and_spliced_video
    exporter = InvasionStudio::KdenliveExporter.new(@folder, quiet: true)

    def exporter.gather_metadata_for(path)
      { duration: 5.0, width: 320, height: 240, fps: 30 }
    end

    output_path = File.join(@folder, 'test.kdenlive')
    exporter.run!(output_path)

    assert File.exist?(output_path), "Kdenlive file should exist"
    assert File.exist?(File.join(@folder, 'combined.mp4')), "Spliced video should exist"

    content = File.read(output_path)

    # Basic structure
    assert_includes content, "<?xml version='1.0' encoding='utf-8'?>"
    assert_includes content, '<mlt LC_NUMERIC="C" producer="main_bin"'

    # Project profile is pinned to 2K regardless of source resolution
    assert content =~ /<profile [^>]*width="2560" height="1440"/,
           "profile should be 2560x1440"
    assert_includes content, '<property name="kdenlive:docproperties.profile">2560x1440_30fps</property>'

    # Single video source referenced
    assert_includes content, '<chain id="chain0"'
    assert_includes content, '<chain id="chain5"'
    
    # Should reference the spliced video basename
    assert_includes content, 'combined.mp4'

    # Sequence tractor with UUID as ID
    assert content =~ /<tractor id="\{[0-9a-f-]+\}"/
    assert_includes content, '<property name="kdenlive:uuid">'
    assert_includes content, '<property name="kdenlive:clipname">Sequence 1</property>'

    # Track structure
    assert_includes content, '<track hide="audio" producer="playlist8"/>'
    assert_includes content, '<track hide="video" producer="playlist0"/>'

    # Kdenlive document properties in main_bin
    assert_includes content, '<property name="kdenlive:docproperties.version">1.1</property>'
    assert_includes content, '<property name="xml_retain">1</property>'

    # Project tractor
    assert_includes content, '<property name="kdenlive:projectTractor">1</property>'
  end

  def test_audio_chains_map_to_distinct_audio_streams
    exporter = InvasionStudio::KdenliveExporter.new(@folder, quiet: true)

    def exporter.gather_metadata_for(path)
      { duration: 5.0, width: 320, height: 240, fps: 30 }
    end

    output_path = File.join(@folder, 'test.kdenlive')
    exporter.run!(output_path)
    content = File.read(output_path)

    chains = content.scan(/<chain id="chain(\d)".*?<\/chain>/m).to_h { |m| [m[0].to_i, content[/<chain id="chain#{m[0]}".*?<\/chain>/m]] }

    # Audio chains 0-3: each selects its own audio stream (video stream is 0,
    # audio streams follow at 1-4), video disabled. Mapping is inverted:
    # MLT tracks are listed bottom-to-top, so chain0 is kdenlive's A4 and
    # must play source audio track 4; chain3 is A1 and plays track 1.
    4.times do |i|
      assert_includes chains[i], "<property name=\"audio_index\">#{4 - i}</property>",
                      "chain#{i} should select audio stream #{4 - i}"
      assert_includes chains[i], "<property name=\"astream\">#{3 - i}</property>"
      assert_includes chains[i], '<property name="video_index">-1</property>'
    end

    # Video chain 4: video only
    assert_includes chains[4], '<property name="video_index">0</property>'
    assert_includes chains[4], '<property name="audio_index">-1</property>'

    # Bin chain 5: default stream selection
    refute_includes chains[5], '<property name="audio_index">'
  end

  def test_run_uses_default_output_path
    exporter = InvasionStudio::KdenliveExporter.new(@folder, quiet: true)

    def exporter.gather_metadata_for(path)
      { duration: 5.0, width: 320, height: 240, fps: 30 }
    end

    exporter.run!
    default_path = File.join(@folder, 'timeline.kdenlive')

    assert File.exist?(default_path)
    assert File.exist?(File.join(@folder, 'combined.mp4'))
  end

  def test_run_raises_when_no_clips_found
    empty_folder = '/tmp/empty_clips'
    FileUtils.mkdir_p(empty_folder)

    exporter = InvasionStudio::KdenliveExporter.new(empty_folder, quiet: true)
    assert_raises(InvasionStudio::Error) do
      exporter.run!
    end
  ensure
    FileUtils.rm_rf(empty_folder) if defined?(empty_folder)
  end

  def test_frames_to_timecode_format
    exporter = InvasionStudio::KdenliveExporter.new(@folder, quiet: true)

    assert_equal "00:00:00.000", exporter.send(:frames_to_timecode, 0, 30)
    assert_equal "00:00:01.000", exporter.send(:frames_to_timecode, 30, 30)
    assert_equal "00:00:10.000", exporter.send(:frames_to_timecode, 300, 30)
    assert_equal "00:00:00.033", exporter.send(:frames_to_timecode, 1, 30)
  end

  def test_negative_frames_returns_zero_timecode
    exporter = InvasionStudio::KdenliveExporter.new(@folder, quiet: true)
    assert_equal "00:00:00.000", exporter.send(:frames_to_timecode, -5, 30)
  end
end
