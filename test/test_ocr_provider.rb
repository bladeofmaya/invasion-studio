require 'test_helper'

class TestOCRProvider < Minitest::Test
  def test_provider_is_abstract
    provider = InvasionStudio::OCR::Provider.new
    assert_raises(NotImplementedError) do
      provider.recognize('test.jpg')
    end
  end

  def test_provider_name
    provider = InvasionStudio::OCR::Provider.new
    assert_equal '', provider.name # Base Provider class has no suffix to strip
  end
end

class TestTesseractProvider < Minitest::Test
  def setup
    @provider = InvasionStudio::OCR::TesseractProvider.new
  end

  def test_tesseract_provider_name
    assert_equal 'tesseract', @provider.name
  end

  def test_tesseract_provider_recognizes_sample_image
    skip unless tesseract_installed?

    result = @provider.recognize('test/samples/invasion_start.jpg')

    assert_instance_of String, result
    assert result.length > 0, 'Expected some text to be recognized'
    # The sample should contain "Host of Fingers" text
    assert result.downcase.include?('host') || result.downcase.include?('fingers') || result.downcase.include?('defeat'),
           "Expected to find 'Host', 'Fingers', or 'Defeat' in recognized text, got: #{result.inspect}"
  end

  def test_tesseract_provider_recognizes_second_sample
    skip unless tesseract_installed?

    result = @provider.recognize('test/samples/invasion_end.jpg')

    assert_instance_of String, result
    assert result.length > 0, 'Expected some text to be recognized'
    # The sample should contain "Returning" text
    assert result.downcase.include?('returning') || result.downcase.include?('world') || result.downcase.include?('died'),
           "Expected to find 'Returning', 'world', or 'died' in recognized text, got: #{result.inspect}"
  end

  private

  def tesseract_installed?
    InvasionStudio.check_tesseract_installed
  end
end

class TestBatchedTesseractProvider < Minitest::Test
  def test_recognize_batch_maps_form_feed_separated_pages
    runner = TestSupport::FakeProcessRunner.new(stdout: "first frame\fsecond frame\n")
    provider = InvasionStudio::OCR::TesseractProvider.new(process_runner: runner)

    results = provider.recognize_batch(['/tmp/frame one.jpg', '/tmp/frame two.jpg'])

    assert_equal ['first frame', 'second frame'], results
    command = runner.commands.fetch(0)[:command]
    assert_equal 'tesseract', command.first
    assert_equal 'stdout', command[2]
    refute File.exist?(command[1])
  end

  def test_recognize_batch_rejects_missing_page_results
    runner = TestSupport::FakeProcessRunner.new(stdout: 'one result')
    provider = InvasionStudio::OCR::TesseractProvider.new(process_runner: runner)

    error = assert_raises(InvasionStudio::OCR::RecognitionError) do
      provider.recognize_batch(%w[first.jpg second.jpg])
    end

    assert_includes error.message, 'returned 1 result for 2 images'
  end
end
