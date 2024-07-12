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
      send("generate_#{segment_type}_clip", @segment, output_file)
      @generated_file = output_file
    end

    def file_exists?(output_file)
      File.exist?(output_file)
    end

    private

    def segment_type
      @segment.start_video != @segment.end_video ? :multi_file : :single_file
    end

    def generate_single_file_clip(segment, output_file)
      system(
        "ffmpeg",
        "-i", segment.start_video,
        "-ss", segment.start_time,
        "-to", segment.end_time,
        "-map", "0",  # Include all streams from the input
        "-c", "copy", # Copy without re-encoding
        output_file
        # "-avoid_negative_ts", "make_zero", # Adjust timestamps
      )
    end

    # TODO: Write a test for this one here
    def generate_multi_file_clip(segment, output_file)
      require 'tmpdir'

      Dir.mktmpdir do |temp_dir|
        temp_file1 = File.join(temp_dir, "tmp001.mp4")
        temp_file2 = File.join(temp_dir, "tmp002.mp4")
        concat_list = File.join(temp_dir, "concat_list.txt")

        # Cut from start_video
        system(
          "ffmpeg", "-i", segment.start_video,
          "-ss", segment.start_time,
          "-c", "copy",
          "-map", "0",
          temp_file1
        )

        # Cut from end_video
        system(
          "ffmpeg", "-i", segment.end_video,
          "-to", segment.end_time,
          "-c", "copy",
          "-map", "0",
          temp_file2
        )

        # Concatenate the two parts
        File.write(concat_list, "file '#{temp_file1}'\nfile '#{temp_file2}'")
        system(
          "ffmpeg", "-f", "concat",
          "-safe", "0",
          "-i", concat_list,
          "-c", "copy",
          "-map", "0",
          output_file
        )
      end
    end
  end
end
