require 'test_helper'

class TestExecutables < Minitest::Test
  def test_uses_path_lookup_by_default
    assert_equal 'ffmpeg', InvasionStudio::Executables.ffmpeg({})
    assert_equal 'ffprobe', InvasionStudio::Executables.ffprobe({})
    assert_equal 'tesseract', InvasionStudio::Executables.tesseract({})
  end

  def test_uses_packaged_tool_overrides
    environment = {
      'INVASION_STUDIO_FFMPEG' => '/app/tools/ffmpeg',
      'INVASION_STUDIO_FFPROBE' => '/app/tools/ffprobe',
      'INVASION_STUDIO_TESSERACT' => '/app/tools/tesseract'
    }

    assert_equal '/app/tools/ffmpeg', InvasionStudio::Executables.ffmpeg(environment)
    assert_equal '/app/tools/ffprobe', InvasionStudio::Executables.ffprobe(environment)
    assert_equal '/app/tools/tesseract', InvasionStudio::Executables.tesseract(environment)
  end

  def test_ignores_empty_overrides
    assert_equal 'ffmpeg', InvasionStudio::Executables.ffmpeg('INVASION_STUDIO_FFMPEG' => '')
  end
end
