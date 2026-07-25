module InvasionStudio
  class Video
    CACHE_VERSION = 2
    attr_reader :path, :options

    def initialize(path, options = {})
      @path = path
      @options = options
    end

    def frames(option_overrides = {})
      @frames ||= load_frames(@options.merge(option_overrides))
    end

    def metadata
      @metadata ||= OCRWorker.new(@path, nil, @options).video_metadata
    end

    def cached_data_exists?
      File.exist?(cache_file_path)
    end

    private

    def load_frames(processing_options)
      if cached_data_exists? && !processing_options[:no_cache]
        cached = load_cached_data(processing_options)
        return cached if cached
      end

      process_frames(processing_options).tap { |frames| cache_data(frames, processing_options) }
    end

    def process_frames(processing_options)
      OCRWorker.new(@path, nil, processing_options).run!
    end

    def cache_file_path
      FileUtils.mkdir_p(Paths.cache_dir, mode: 0o700)
      File.join(Paths.cache_dir, "#{VideoHasher.hash(@path)}.yml")
    end

    def load_cached_data(processing_options)
      cached = YAML.safe_load(
        File.read(cache_file_path),
        permitted_classes: [Symbol],
        aliases: false
      )
      return nil unless cached.is_a?(Hash)
      return nil unless cached['version'] == CACHE_VERSION
      return nil unless cached['fingerprint'] == cache_fingerprint(processing_options)

      cached.fetch('frames').map do |item|
        Frame.new(item['number'], item['text'], item['timestamp'], item['video_path'])
      end
    rescue Psych::Exception, KeyError, TypeError
      nil
    end

    def cache_data(frames, processing_options)
      data = {
        'version' => CACHE_VERSION,
        'fingerprint' => cache_fingerprint(processing_options),
        'frames' => frames.map do |frame|
          {
            'number' => frame.number,
            'text' => frame.text,
            'timestamp' => frame.timestamp,
            'video_path' => frame.video_path
          }
        end
      }
      temporary = "#{cache_file_path}.#{Process.pid}.tmp"
      File.write(temporary, data.to_yaml)
      File.rename(temporary, cache_file_path)
    ensure
      File.delete(temporary) if temporary && File.exist?(temporary)
    end

    def cache_fingerprint(processing_options)
      stat = File.stat(@path)
      {
        'path' => File.expand_path(@path),
        'size' => stat.size,
        'mtime_ns' => stat.mtime.nsec + (stat.mtime.to_i * 1_000_000_000),
        'fps' => processing_options[:fps] || 1,
        'crop_version' => 1,
        'ocr_provider' => (processing_options[:ocr_provider_name] || 'tesseract').to_s
      }
    rescue Errno::ENOENT
      {
        'path' => File.expand_path(@path),
        'missing' => true,
        'fps' => processing_options[:fps] || 1
      }
    end
  end
end
