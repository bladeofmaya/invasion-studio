module InvasionExtractor
  class Clip
    attr_accessor :generated_file, :segment

    def initialize(segment)
      @segment = segment
      @segment.start_time = TimeHelper.wind_back(@segment.start_time, 10.0)
      @segment.end_time = TimeHelper.wind_forward(@segment.end_time, 7.5)

      @generated_file = nil
    end

    def write(output_file)
      # Create a log file for ffmpeg output
      log_file = File.join(File.dirname(output_file), ".#{File.basename(output_file, '.*')}_ffmpeg.log")
      send("generate_#{segment_type}_clip", @segment, output_file, log_file)
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
        "-y", # Overwrite output
        output_file,
        ">", log_file, "2>&1"
      ].join(" ")

      system(cmd)
    end

    def generate_multi_file_clip(segment, output_file, log_file)
      require 'tmpdir'

      Dir.mktmpdir do |temp_dir|
        temp_file1 = File.join(temp_dir, "tmp001.mp4")
        temp_file2 = File.join(temp_dir, "tmp002.mp4")
        concat_list = File.join(temp_dir, "concat_list.txt")
        temp_log = File.join(temp_dir, "ffmpeg.log")

        # Cut from start_video
        cmd1 = [
          "ffmpeg",
          "-i", segment.start_video,
          "-ss", segment.start_time,
          "-c", "copy",
          "-map", "0",
          "-y",
          temp_file1,
          ">", temp_log, "2>&1"
        ].join(" ")
        system(cmd1)

        # Cut from end_video
        cmd2 = [
          "ffmpeg",
          "-i", segment.end_video,
          "-to", segment.end_time,
          "-c", "copy",
          "-map", "0",
          "-y",
          temp_file2,
          ">>", temp_log, "2>&1"
        ].join(" ")
        system(cmd2)

        # Concatenate the two parts
        File.write(concat_list, "file '#{temp_file1}'\nfile '#{temp_file2}'")
        cmd3 = [
          "ffmpeg",
          "-f", "concat",
          "-safe", "0",
          "-i", concat_list,
          "-c", "copy",
          "-map", "0",
          "-y",
          output_file,
          ">>", temp_log, "2>&1"
        ].join(" ")
        system(cmd3)

        # Copy log to final location
        FileUtils.cp(temp_log, log_file) if File.exist?(temp_log)
      end
    end
  end
end
