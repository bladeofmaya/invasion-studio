require 'test_helper'

class TestEngine < Minitest::Test
  OcrResult = Data.define(:videos, :errors)

  def test_extraction_carries_ocr_events_into_project_markers_without_processing_media
    Dir.mktmpdir do |folder|
      frames = [
        InvasionStudio::Frame.new(1, 'Defeat the Host of Fingers', '00:00:10', 'recording.mp4'),
        InvasionStudio::Frame.new(2, 'Furled Finger Alice has died', '00:00:15', 'recording.mp4'),
        InvasionStudio::Frame.new(3, 'Hunter Bob has died', '00:00:20', 'recording.mp4'),
        InvasionStudio::Frame.new(4, 'Returning to your world', '00:00:30', 'recording.mp4')
      ]
      video = Struct.new(:path, :items).new('recording.mp4', frames)
      def video.frames(*) = items
      writer = Object.new
      def writer.write(_segment, output, _log)
        File.write(output, 'dummy')
        true
      end
      engine = InvasionStudio::Engine.new(['recording.mp4'], quiet: true,
        outdir: File.join(folder, 'clips'), pad_start: 5, pad_end: 0,
        video_factory: ->(*) { video }, clip_writer: writer)
      engine.run!
      created = engine.clip_extraction_stage.created
      assert_equal [10.0, 15.0], created.first[:markers].map { |marker| marker['time'] }
      importer = InvasionStudio::ExtractionImporter.new(folder)
      assert_equal 1, importer.record(created)
      project = InvasionStudio::Project.new(folder)
      assert_equal %w[phantom_defeated hunter_defeated], project.clips.first['markers'].map { |marker| marker['event_type'] }
    end
  end

  class Stage
    attr_reader :arguments

    def initialize(result)
      @result = result
    end

    def run(argument)
      @arguments = argument
      @result
    end
  end

  def test_coordinates_injected_stages_and_collects_errors
    video = Object.new
    ocr_error = RuntimeError.new('ocr')
    extract_error = RuntimeError.new('extract')
    ocr = Stage.new(OcrResult.new([video], [['video.mp4', ocr_error]]))
    scan = Stage.new([:segment])
    extraction = Stage.new([['clip.mp4', extract_error]])
    scanner = Struct.new(:invasion_segments).new([:segment])
    engine = InvasionStudio::Engine.new(
      ['video.mp4'],
      video_factory: ->(_path, _options) { video },
      scanner_factory: ->(_videos) { scanner },
      ocr_stage: ocr,
      scan_stage: scan,
      clip_extraction_stage: extraction
    )

    assert_same engine, engine.run!
    assert_equal [video], ocr.arguments
    assert_same scanner, scan.arguments
    assert_equal [:segment], extraction.arguments
    assert_equal [ocr_error, extract_error], engine.errors.map(&:last)
  end

  def test_scan_command_does_not_run_extraction_stage
    video = Object.new
    ocr = Stage.new(OcrResult.new([video], []))
    scan = Stage.new([])
    extraction = Stage.new([])
    scanner = Struct.new(:invasion_segments).new([])
    engine = InvasionStudio::Engine.new(
      ['video.mp4'],
      command: 'scan',
      video_factory: ->(_path, _options) { video },
      scanner_factory: ->(_videos) { scanner },
      ocr_stage: ocr,
      scan_stage: scan,
      clip_extraction_stage: extraction
    )

    engine.run!

    assert_nil extraction.arguments
  end
end
