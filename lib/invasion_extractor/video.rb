module InvasionExtractor
  class Video
    attr_reader :video, :frames

    def initialize(video)
      @video = video
      @frames = []
    end

    def generate_data!
      if cached_data_exists?
        load_cached_data
      else
        process_frames
        cache_data
      end
      self
    end

    def metadata
      ocr_worker.video_metadata
    end

    private

    def ocr_worker
      worker ||= InvasionExtractor::OCRWorker.new(video)
    end

    def process_frames
      @frames = InvasionExtractor::OCRWorker.new(@video).run!
    end

    # TODO: Use a cache folder in the home directory?
    def cache_file_path
      cache_dir = File.expand_path('../../tmp/ocr_cache', __dir__)
      FileUtils.mkdir_p(cache_dir)
      File.join(cache_dir, "#{video_hash}.yml")
    end

    def video_hash
      File.basename(@video)
    end

    def cached_data_exists?
      File.exist?(cache_file_path)
    end

    def load_cached_data
      cached_data = YAML.load_file(cache_file_path)
      @frames = cached_data.map do |item|
        InvasionExtractor::Frame.new(item[:number], item[:text], item[:timestamp], item[:video_file])
      end
    end

    def cache_data
      data_to_cache = @frames.map do |frame|
        {
          number: frame.number,
          text: frame.text,
          timestamp: frame.timestamp,
          video_file: frame.video_file
        }
      end
      File.write(cache_file_path, data_to_cache.to_yaml)
    end
  end
end
