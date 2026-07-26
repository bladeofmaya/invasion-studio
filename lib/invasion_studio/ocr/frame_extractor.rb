# frozen_string_literal: true

module InvasionStudio
  module OCR
    class FrameExtractor
      def initialize(process_runner: ProcessRunner.new, gpu_detector: GPUDetector)
        @process_runner = process_runner
        @gpu_detector = gpu_detector
      end

      def start(video_path:, frames_dir:, fps:, crop:, options: {})
        command = command_for(video_path, frames_dir, fps, crop, options)
        Thread.new do
          success = @process_runner.run(*command, log_path: File::NULL)
          raise Error, "ffmpeg failed while extracting frames from #{video_path}" unless success

          true
        end.tap { |thread| thread.report_on_exception = false }
      end

      private

      def command_for(video_path, frames_dir, fps, crop, options)
        filter = "fps=#{fps},crop=#{crop[:width]}:#{crop[:height]}:#{crop[:x]}:#{crop[:y]}"
        acceleration = []
        if options[:hwaccel] && @gpu_detector.vaapi_available?
          acceleration = @gpu_detector.ffmpeg_hwaccel_args
          filter = "fps=#{fps},hwdownload,format=nv12,crop=#{crop[:width]}:#{crop[:height]}:#{crop[:x]}:#{crop[:y]}"
        end

        ['ffmpeg', '-threads', (options[:ffmpeg_threads] || 4).to_s, *acceleration,
         '-i', video_path, '-vf', filter, '-qscale:v', '5',
         File.join(frames_dir, 'frame_%06d.jpg')]
      end
    end
  end
end
