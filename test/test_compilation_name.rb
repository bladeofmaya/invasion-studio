require 'test_helper'

class TestCompilationName < Minitest::Test
  def test_accepts_human_readable_unicode_names
    assert InvasionStudio::CompilationName.valid?('Best Runs (Schöne Kämpfe)')
  end

  def test_rejects_names_that_are_not_portable_folder_names
    ['', '.', '..', 'bad/name', 'bad\\name', 'bad:name', 'bad*name', "bad\0name",
     'trailing.', 'trailing ', 'CON', 'com1.txt'].each do |name|
      refute InvasionStudio::CompilationName.valid?(name), name.inspect
    end
  end

  def test_identity_is_case_insensitive_and_unicode_normalized
    assert_equal InvasionStudio::CompilationName.identity('Élite'),
                 InvasionStudio::CompilationName.identity("e\u0301LITE")
  end
end
