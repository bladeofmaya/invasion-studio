module InvasionCutter
  class Frame
    attr_accessor :number, :text, :timestamp, :video_file

    def initialize(number, text, timestamp, video_file)
      @number = number
      @text = text
      @timestamp = timestamp
      @video_file = video_file
    end
  end
end
