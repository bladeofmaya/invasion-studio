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
      @runner = options[:process_runner] || ProcessRunner.new
      @generated_file = nil
    end

    def write(output_file)
      log_file = File.join(File.dirname(output_file), ".#{File.basename(output_file, '.*')}_ffmpeg.log")
      success = send("generate_#{segment_type}_clip", @segment, output_file, log_file)
      raise Error, "ffmpeg failed while generating #{output_file}; see #{log_file}" unless success && File.exist?(output_file)

      @generated_file = output_file
    end

    def file_exists?(output_file)
      File.exist?(output_file)
    end

    private

    def segment_type
      @segment.start_video != @segment.end_video ? :multi_file : :single_file
    end

    def generate_single_file_clip(segment, output_file, log_file)
      cmd = [
        "ffmpeg",
        "-i", segment.start_video,
        "-ss", segment.start_time,
        "-to", segment.end_time,
        "-map", "0",
        "-c", "copy",
        "-y",
        output_file
      ]

      @runner.run(*cmd, log_path: log_file)
    end

    def generate_multi_file_clip(segment, output_file, log_file)
      require 'tmpdir'

      Dir.mktmpdir do |temp_dir|
        temp_file1 = File.join(temp_dir, "tmp001.mp4")
        temp_file2 = File.join(temp_dir, "tmp002.mp4")
        concat_list = File.join(temp_dir, "concat_list.txt")
        temp_log = File.join(temp_dir, "ffmpeg.log")

        cmd1 = [
          "ffmpeg",
          "-i", segment.start_video,
          "-ss", segment.start_time,
          "-c", "copy",
          "-map", "0",
          "-y",
          temp_file1
        ]
        return false unless @runner.run(*cmd1, log_path: temp_log)

        cmd2 = [
          "ffmpeg",
          "-i", segment.end_video,
          "-to", segment.end_time,
          "-c", "copy",
          "-map", "0",
          "-y",
          temp_file2
        ]
        return false unless @runner.run(*cmd2, log_path: temp_log)

        File.write(concat_list, "file '#{temp_file1}'\nfile '#{temp_file2}'")
        cmd3 = [
          "ffmpeg",
          "-f", "concat",
          "-safe", "0",
          "-i", concat_list,
          "-c", "copy",
          "-map", "0",
          "-y",
          output_file
        ]
        success = @runner.run(*cmd3, log_path: temp_log)

        FileUtils.cp(temp_log, log_file) if File.exist?(temp_log)
        success
      end
    end
  end
end
