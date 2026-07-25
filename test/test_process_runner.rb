require 'test_helper'

class TestProcessRunner < Minitest::Test
  def test_capture_preserves_arguments_without_shell_interpolation
    dangerous_argument = 'name with spaces; $(touch never-created)'

    result = InvasionStudio::ProcessRunner.new.capture(
      Gem.ruby, '-e', 'print ARGV.fetch(0)', dangerous_argument
    )

    assert result.success?
    assert_equal dangerous_argument, result.stdout
  end
end
