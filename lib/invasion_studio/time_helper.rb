module InvasionStudio
  class TimeHelper
    def self.wind_back(time_string, seconds)
      time = parse_time(time_string)
      new_time = [time - seconds, 0.0].max
      format_time(new_time)
    end

    def self.wind_forward(time_string, seconds)
      time = parse_time(time_string)
      new_time = time + seconds
      format_time(new_time)
    end

    private

    def self.parse_time(time_string)
      match = /\A(\d+):(\d{2}):(\d{2}(?:\.\d+)?)\z/.match(time_string.to_s)
      raise ArgumentError unless match

      hours, minutes, seconds = match.captures
      raise ArgumentError if minutes.to_i >= 60 || seconds.to_f >= 60

      (hours.to_i * 3600) + (minutes.to_i * 60) + seconds.to_f
    rescue ArgumentError, TypeError
      raise ArgumentError, "Invalid time format: #{time_string}"
    end

    def self.format_time(total_seconds)
      hours = (total_seconds / 3600).floor
      minutes = ((total_seconds % 3600) / 60).floor
      seconds = total_seconds % 60
      format('%02d:%02d:%06.3f', hours, minutes, seconds)
    end
  end
end
