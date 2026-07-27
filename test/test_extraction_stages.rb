require 'test_helper'
require 'tmpdir'

class TestExtractionStages < Minitest::Test
  class Reporter
    attr_reader :events

    def initialize
      @events = []
    end

    def ocr_frame_options(_video) = {}
    def method_missing(name, *arguments) = @events << [name, *arguments]
    def respond_to_missing?(_name, _private = false) = true
  end

  class FakeVideo
    attr_reader :path

    def initialize(path, frames: [], error: nil)
      @path = path
      @frames = frames
      @error = error
    end

    def frames(_options = {})
      raise @error if @error

      @frames
    end
  end

  class FakeClip
    attr_reader :written_path

    def file_exists?(_path) = false
    def write(path) = @written_path = path
  end

  def test_ocr_stage_returns_successes_and_continues_after_configured_errors
    reporter = Reporter.new
    good = FakeVideo.new('good.mp4', frames: [:frame])
    bad = FakeVideo.new('bad.mp4', error: RuntimeError.new('broken'))
    stage = InvasionStudio::Extraction::OcrStage.new(
      { continue_on_error: true },
      reporter: reporter
    )

    result = stage.run([good, bad])

    assert_equal [good], result.videos
    assert_equal [['bad.mp4', 'broken']], result.errors.map { |path, error| [path, error.message] }
    assert_includes reporter.events.map(&:first), :video_error
  end

  def test_scan_stage_returns_scanner_segments
    reporter = Reporter.new
    scanner = Struct.new(:invasion_segments, :matched_frames).new([:segment], [])

    segments = InvasionStudio::Extraction::ScanStage.new(reporter: reporter).run(scanner)

    assert_equal [:segment], segments
    assert_equal %i[scanning scan_complete], reporter.events.map(&:first)
  end

  FakeSegment = Struct.new(:start_video)

  def test_clip_extraction_stage_names_and_writes_clips
    Dir.mktmpdir do |directory|
      reporter = Reporter.new
      clip = FakeClip.new
      factory = ->(_segment, _options) { clip }
      stage = InvasionStudio::Extraction::ClipExtractionStage.new(
        { outdir: directory, prefix: 'duel' },
        reporter: reporter,
        clip_factory: factory
      )

      errors = stage.run([FakeSegment.new('/recordings/a.mp4')])

      assert_empty errors
      assert_equal File.join(directory, 'duel_00001.mp4'), clip.written_path
      assert_includes reporter.events.map(&:first), :clip_extracted
    end
  end

  def test_clip_extraction_stage_continues_numbering_across_prefixes
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, 'str-invasions_00021.mp4'), 'existing')
      clip = FakeClip.new
      stage = InvasionStudio::Extraction::ClipExtractionStage.new(
        { outdir: directory, prefix: 'clip' },
        reporter: Reporter.new,
        clip_factory: ->(_segment, _options) { clip }
      )

      stage.run([FakeSegment.new('/recordings/a.mp4')])

      assert_equal File.join(directory, 'clip_00022.mp4'), clip.written_path
    end
  end

  def test_clip_extraction_stage_tracks_created_clips_with_sources
    Dir.mktmpdir do |directory|
      clips = [FakeClip.new, FakeClip.new]
      factory = ->(_segment, _options) { clips.shift }
      stage = InvasionStudio::Extraction::ClipExtractionStage.new(
        { outdir: directory, prefix: 'clip' },
        reporter: Reporter.new,
        clip_factory: factory
      )

      stage.run([FakeSegment.new('/recordings/a.mp4'), FakeSegment.new('/recordings/b.mp4')])

      assert_equal(
        [
          { path: File.join(directory, 'clip_00001.mp4'), source: '/recordings/a.mp4' },
          { path: File.join(directory, 'clip_00002.mp4'), source: '/recordings/b.mp4' }
        ],
        stage.created
      )
    end
  end
end
