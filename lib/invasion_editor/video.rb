module InvasionEditor
  class Video
    attr_reader :video, :tmpdir, :frame_data

    def self.process(video)
      new(video).send(:generate_data)
    end

    def initialize(video)
      @video = video
      @tmpdir = File.join(Dir.tmpdir, "invasion_editor_#{Time.now.to_i}")
      FileUtils.mkdir_p(@tmpdir)
      @frame_data = []
    end

    private

    def generate_data
      if cached_data_exists?
        load_cached_data
      else
        generate_frames
        extract_text_from_images
        cleanup
        cache_data
      end
      self
    end

    # This method generates frames from the video file and adds contrast and brightness to the frames.
    # TODO: Research if the process of character recognition can be improved by
    # reducing the aspect ratio of the frames. (e.g. 2560x1440 -> 1280x720)
    def generate_frames
      system("ffmpeg -threads 8 -i #{@video} -vf fps=2,eq=contrast=10:brightness=1.0 -preset ultrafast #{@tmpdir}/frame_%04d.jpg")
    end

    def extract_text_from_images
      frames = Dir.glob("#{@tmpdir}/*.jpg").sort
      @frame_data = InvasionEditor::Ocr.run(frames, @video)
    end

    def cleanup
      FileUtils.rm_rf(@tmpdir)
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
      @frame_data = cached_data.map do |item|
        InvasionEditor::Frame.new(item[:number], item[:text], item[:timestamp], item[:video_file])
      end
    end

    def cache_data
      data_to_cache = @frame_data.map do |frame|
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
