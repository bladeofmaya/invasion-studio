require 'test_helper'

class TestTimeHelper < Minitest::Test
  def test_winds_without_date_or_timezone_arithmetic
    assert_equal '00:00:00.000', InvasionStudio::TimeHelper.wind_back('00:00:02.000', 5)
    assert_equal '00:01:02.500', InvasionStudio::TimeHelper.wind_forward('00:00:59.500', 3)
  end

  def test_supports_durations_longer_than_one_day
    assert_equal '25:00:01.000', InvasionStudio::TimeHelper.wind_forward('24:59:59.000', 2)
  end

  def test_rejects_invalid_timestamp
    assert_raises(ArgumentError) { InvasionStudio::TimeHelper.wind_forward('12:99:00', 1) }
  end
end
