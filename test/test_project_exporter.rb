require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'rexml/document'
require 'rexml/xpath'

class TestProjectExporter < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_export_group_with_no_clips_raises
    project = InvasionStudio::Project.new(@tmp_dir)
    exporter = InvasionStudio::ProjectExporter.new(project, quiet: true)

    assert_raises(InvasionStudio::Error) do
      exporter.export_group('Video 1')
    end
  end

  def test_builds_chapters_from_clip_titles_with_filename_fallback
    project = InvasionStudio::Project.new(@tmp_dir)
    exporter = InvasionStudio::ProjectExporter.new(project, quiet: true)
    clips = [
      { 'title' => 'First invasion', 'filename' => 'one.mp4', 'duration' => 10.5 },
      { 'title' => ' ', 'filename' => 'two.mp4', 'duration' => 4.0 }
    ]

    assert_equal [
      { title: 'First invasion', start_time: 0.0, end_time: 10.5 },
      { title: 'two.mp4', start_time: 10.5, end_time: 14.5 }
    ], exporter.send(:build_chapters, clips)
  end

  def test_chapters_prefer_current_file_duration_over_stale_database_duration
    project = InvasionStudio::Project.new(@tmp_dir)
    exporter = InvasionStudio::ProjectExporter.new(
      project,
      quiet: true,
      metadata_probe: ->(_path) { { duration: 8.0 } }
    )
    clips = [{
      'title' => 'Finalized clip',
      'filename' => 'one.mp4',
      'resolved_path' => File.join(@tmp_dir, 'one.mp4'),
      'duration' => 10.0
    }]

    chapter = exporter.send(:build_chapters, clips).first

    assert_equal 8.0, chapter[:end_time]
  end

  def test_ffmetadata_contains_titled_mp4_chapters
    project = InvasionStudio::Project.new(@tmp_dir)
    exporter = InvasionStudio::ProjectExporter.new(project, quiet: true)
    chapters = [{ title: 'Win = close #1 \\ rematch', start_time: 0.0, end_time: 10.5 }]

    metadata = exporter.send(:build_chapter_metadata, chapters)

    assert_includes metadata, '[CHAPTER]'
    assert_includes metadata, 'START=0'
    assert_includes metadata, 'END=10500'
    assert_includes metadata, 'title=Win \\= close \\#1 \\\\ rematch'
  end

  def test_export_embeds_the_same_chapters_in_mp4_and_kdenlive
    clips = [
      { 'title' => 'Opening', 'filename' => 'one.mp4', 'duration' => 2.0 },
      { 'title' => 'Finish', 'filename' => 'two.mp4', 'duration' => 3.0 }
    ]
    project = Struct.new(:folder_path, :clips) do
      def group_clips(_name) = clips
      def resolve_clip_path(clip) = File.join(folder_path, clip['filename'])
    end.new(@tmp_dir, clips)
    runner = TestSupport::FakeProcessRunner.new
    exporter = InvasionStudio::ProjectExporter.new(
      project,
      quiet: true,
      process_runner: runner,
      metadata_probe: lambda { |path|
        durations = { 'one.mp4' => 2.0, 'two.mp4' => 3.0, 'best.mp4' => 5.0 }
        { duration: durations.fetch(File.basename(path)), width: 1920, height: 1080, fps: 30 }
      }
    )

    _video_path, project_path = exporter.export_group('Best')

    command = runner.commands.first.fetch(:command)
    assert_includes command, '-map_chapters'
    assert_equal '1', command[command.index('-map_chapters') + 1]
    xml = File.read(project_path)
    assert_includes xml, '&quot;comment&quot;:&quot;Opening&quot;'
    assert_includes xml, '&quot;comment&quot;:&quot;Finish&quot;'
    assert_includes xml, '&quot;pos&quot;:60'
  end

  def test_export_uses_project_audio_settings_for_mp4_and_kdenlive
    clips = [{ 'filename' => 'one.mp4', 'duration' => 2.0 }]
    project = Struct.new(:folder_path, :clips, :video_settings) do
      def group_clips(_name) = clips
      def resolve_clip_path(clip) = File.join(folder_path, clip['filename'])
    end.new(
      @tmp_dir,
      clips,
      { 'audio_track_count' => 2, 'default_audio_track' => 2 }
    )
    runner = TestSupport::FakeProcessRunner.new
    exporter = InvasionStudio::ProjectExporter.new(
      project,
      quiet: true,
      process_runner: runner,
      metadata_probe: lambda { |path|
        { duration: File.basename(path) == 'one.mp4' ? 2.0 : 2.0, width: 1920, height: 1080, fps: 30,
          audio_stream_count: 4 }
      }
    )

    _video_path, project_path = exporter.export_group('Best')

    command = runner.commands.first.fetch(:command)
    assert_includes command.each_cons(2).to_a, ['-map', '0:v:0?']
    assert_includes command.each_cons(2).to_a, ['-map', '0:a:0?']
    assert_includes command.each_cons(2).to_a, ['-map', '0:a:1?']
    refute_includes command.each_cons(2).to_a, ['-map', '0:a:2?']
    assert_includes command.each_cons(2).to_a, ['-disposition:a:1', 'default']

    document = REXML::Document.new(File.read(project_path))
    audio_chains = REXML::XPath.match(
      document, '/mlt/chain/property[@name="audio_index" and text() != "-1"]'
    )
    assert_equal 2, audio_chains.length
  end
end
