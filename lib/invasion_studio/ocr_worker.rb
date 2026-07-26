module InvasionStudio
  class OCRWorker
    attr_reader :video_path, :video_metadata

    def initialize(video_path, ocr_provider = nil, options = {})
      @video_path = video_path
      @options = options
      process_runner = options[:process_runner] || ProcessRunner.new
      @metadata_probe = options[:metadata_probe] || OCR::VideoMetadataProbe.new(
        process_runner: process_runner,
        debug: options[:debug]
      )
      @video_metadata = @metadata_probe.call(video_path)
      @crop_geometry = options[:crop_geometry] || OCR::CropGeometry.new
      @frame_extractor = options[:frame_extractor] || OCR::FrameExtractor.new(process_runner: process_runner)
      provider = ocr_provider || OCR::TesseractProvider.new
      worker_policy = options[:worker_policy] || OCR::WorkerPolicy.new(
        ocr_workers: options[:ocr_workers],
        ocr_queue_size: options[:ocr_queue_size]
      )
      @ocr_pool = options[:ocr_pool] || OCR::OcrPool.new(
        provider: provider,
        worker_policy: worker_policy,
        frame_discovery: options[:frame_discovery] || OCR::FrameDiscovery.new
      )
    end

    def run!
      fps = @options[:fps] || 1

      Dir.mktmpdir do |frames_dir|
        producer = @frame_extractor.start(
          video_path: @video_path,
          frames_dir: frames_dir,
          fps: fps,
          crop: @crop_geometry.call(@video_metadata || {}),
          options: @options
        )
        results = @ocr_pool.process(
          frames_dir: frames_dir,
          producer: producer,
          fps: fps,
          total_frames: estimated_total_frames(fps),
          video_path: @video_path,
          extract_progress: @options[:extract_progress_callback],
          ocr_progress: @options[:progress_callback]
        )
        producer.value
        results.sort_by(&:number)
      end
    end

    private

    def estimated_total_frames(fps)
      return 0 unless @video_metadata && @video_metadata[:duration].positive?

      (@video_metadata[:duration] * fps).to_i
    end
  end
end
