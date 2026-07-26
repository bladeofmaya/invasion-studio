require 'test_helper'

class TestEngine < Minitest::Test
  OcrResult = Data.define(:videos, :errors)

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
