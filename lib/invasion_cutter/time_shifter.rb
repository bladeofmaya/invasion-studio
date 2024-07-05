module InvasionCutter
  class TimeShifter
    def self.wind_back(time_string, seconds)
      time = Time.parse(time_string)
      new_time = time - seconds
      new_time.strftime("%H:%M:%S.%L")
    end

    def self.wind_forward(time_string, seconds)
      time = Time.parse(time_string)
      new_time = time + seconds
      new_time.strftime("%H:%M:%S.%L")
    end
  end
end
