module InvasionExtractor
  class Frame
    attr_accessor :number, :text, :timestamp, :video_path

    def initialize(number, text, timestamp, video_path)
      @number = number
      @text = text
      @timestamp = timestamp
      @video_path = video_path
    end
  end
end
