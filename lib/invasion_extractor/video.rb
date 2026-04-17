module InvasionExtractor
  class Video
    attr_reader :video, :options

    def initialize(video, options = {})
      @video = video
      @options = options
    end

    def frames
      @frames ||= load_frames
    end

    def metadata
      ocr_worker.video_metadata
    end

    # Public method to check if cached data exists
    def cached_data_exists?
      File.exist?(cache_file_path)
    end

    private

    def load_frames
      if cached_data_exists?
        load_cached_data
      else
        process_frames.tap { |frames| cache_data(frames) }
      end
    end

    def ocr_worker
      @ocr_worker ||= InvasionExtractor::OCRWorker.new(video, nil, @options)
    end

    def process_frames
      InvasionExtractor::OCRWorker.new(@video, nil, @options).run!
    end

    # Cache in ~/.invasion_extractor/cache/ for persistence across sessions
    def cache_file_path
      cache_dir = File.join(Dir.home, '.invasion_extractor', 'cache')
      FileUtils.mkdir_p(cache_dir)
      File.join(cache_dir, "#{video_hash}.yml")
    end

    def video_hash
      # Use full path hash for uniqueness, but sanitize for filename
      require 'digest'
      base = File.basename(@video, '.*')
      path_hash = Digest::MD5.hexdigest(File.expand_path(@video))[0..7]
      "#{base}-#{path_hash}"
    end

    def load_cached_data
      cached_data = YAML.load_file(cache_file_path)
      cached_data.map do |item|
        InvasionExtractor::Frame.new(item[:number], item[:text], item[:timestamp], item[:video_file])
      end
    end

    def cache_data(frames)
      data_to_cache = frames.map do |frame|
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
