module InvasionStudio
  class Clip
    attr_reader :generated_file, :segment

    def initialize(segment, options = {})
      pad_start = options[:pad_start] || 10.0
      pad_end = options[:pad_end] || 7.5
      @segment = Scanner::Segment.new(
        TimeHelper.wind_back(segment.start_time, pad_start),
        segment.start_video,
        TimeHelper.wind_forward(segment.end_time, pad_end),
        segment.end_video
      )
      @writer = options[:clip_writer] || ClipWriter.new(
        process_runner: options[:process_runner] || ProcessRunner.new
      )
      @generated_file = nil
    end

    def write(output_file)
      log_file = File.join(File.dirname(output_file), ".#{File.basename(output_file, '.*')}_ffmpeg.log")
      success = @writer.write(@segment, output_file, log_file)
      raise Error, "ffmpeg failed while generating #{output_file}; see #{log_file}" unless success && File.exist?(output_file)

      @generated_file = output_file
    end

    def file_exists?(output_file)
      File.exist?(output_file)
    end

  end
end
