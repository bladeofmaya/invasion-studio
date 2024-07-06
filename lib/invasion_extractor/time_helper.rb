# TODO: Test wind_forward and ffmpeg j
module InvasionExtractor
  class TimeHelper
    def self.wind_back(time_string, seconds)
      time = parse_time(time_string)
      new_time = [time - seconds, Time.parse("00:00:00.000")].max
      format_time(new_time)
    end

    def self.wind_forward(time_string, seconds)
      time = parse_time(time_string)
      new_time = time + seconds
      format_time(new_time)
    end

    private

    def self.parse_time(time_string)
      Time.parse(time_string)
    rescue ArgumentError
      raise ArgumentError, "Invalid time format: #{time_string}"
    end

    def self.format_time(time)
      time.strftime("%H:%M:%S.%L")
    end
  end
end
