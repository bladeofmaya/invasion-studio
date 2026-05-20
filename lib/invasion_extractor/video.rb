module InvasionExtractor
  class Video
    attr_reader :path, :options

    def initialize(path, options = {})
      @path = path
      @options = options
    end

    def frames
      @frames ||= load_frames
    end

    def metadata
      @metadata ||= OCRWorker.new(@path, nil, @options).video_metadata
    end

    def total_frames
      return 0 unless metadata && metadata[:duration] > 0
      ((metadata[:duration] * (@options[:fps] || 2)) + 0.5).to_i
    end

    def cached_data_exists?
      File.exist?(cache_file_path)
    end

    private

    def load_frames
      if cached_data_exists? && !@options[:no_cache]
        load_cached_data
      else
        process_frames.tap { |frames| cache_data(frames) }
      end
    end

    def process_frames
      worker_options = @options.merge(total_frames: total_frames)
      OCRWorker.new(@path, nil, worker_options).run!
    end

    def cache_file_path
      FileUtils.mkdir_p(InvasionExtractor::CACHE_DIR)
      File.join(InvasionExtractor::CACHE_DIR, "#{VideoHasher.hash(@path)}.yml")
    end

    def load_cached_data
      cached_data = YAML.load_file(cache_file_path)
      cached_data.map do |item|
        video_path = item[:video_path] || item[:video_file]
        Frame.new(item[:number], item[:text], item[:timestamp], video_path)
      end
    end

    def cache_data(frames)
      data_to_cache = frames.map do |frame|
        {
          number: frame.number,
          text: frame.text,
          timestamp: frame.timestamp,
          video_path: frame.video_path
        }
      end
      File.write(cache_file_path, data_to_cache.to_yaml)
    end
  end
end
