require 'test_helper'

class TestOCRProvider < Minitest::Test
  def test_provider_is_abstract
    provider = InvasionExtractor::OCR::Provider.new
    assert_raises(NotImplementedError) do
      provider.recognize('test.jpg')
    end
  end

  def test_provider_name
    provider = InvasionExtractor::OCR::Provider.new
    assert_equal '', provider.name # Base Provider class has no suffix to strip
  end
end

class TestTesseractProvider < Minitest::Test
  def setup
    @provider = InvasionExtractor::OCR::TesseractProvider.new
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
    InvasionExtractor.check_tesseract_installed
  end
end
