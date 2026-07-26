# frozen_string_literal: true

module InvasionStudio
  class ClipWriter
    def initialize(process_runner: ProcessRunner.new, single_file_writer: nil, multi_file_writer: nil)
      @single_file_writer = single_file_writer || ClipWriters::SingleFile.new(process_runner)
      @multi_file_writer = multi_file_writer || ClipWriters::MultiFile.new(process_runner)
    end

    def write(segment, output_file, log_file)
      writer_for(segment).write(segment, output_file, log_file)
    end

    private

    def writer_for(segment)
      segment.start_video == segment.end_video ? @single_file_writer : @multi_file_writer
    end
  end

  module ClipWriters
    class SingleFile
      def initialize(process_runner)
        @process_runner = process_runner
      end

      def write(segment, output_file, log_file)
        command = [
          'ffmpeg', '-i', segment.start_video,
          '-ss', segment.start_time,
          '-to', segment.end_time,
          '-map', '0', '-c', 'copy', '-y', output_file
        ]
        @process_runner.run(*command, log_path: log_file)
      end
    end

    class MultiFile
      def initialize(process_runner)
        @process_runner = process_runner
      end

      def write(segment, output_file, log_file)
        Dir.mktmpdir do |directory|
          first = File.join(directory, 'tmp001.mp4')
          second = File.join(directory, 'tmp002.mp4')
          concat_list = File.join(directory, 'concat_list.txt')
          temporary_log = File.join(directory, 'ffmpeg.log')

          return false unless cut_start(segment, first, temporary_log)
          return false unless cut_end(segment, second, temporary_log)

          File.write(concat_list, "file '#{first}'\nfile '#{second}'")
          success = concat(concat_list, output_file, temporary_log)
          FileUtils.cp(temporary_log, log_file) if File.exist?(temporary_log)
          success
        end
      end

      private

      def cut_start(segment, output, log)
        @process_runner.run(
          'ffmpeg', '-i', segment.start_video, '-ss', segment.start_time,
          '-c', 'copy', '-map', '0', '-y', output,
          log_path: log
        )
      end

      def cut_end(segment, output, log)
        @process_runner.run(
          'ffmpeg', '-i', segment.end_video, '-to', segment.end_time,
          '-c', 'copy', '-map', '0', '-y', output,
          log_path: log
        )
      end

      def concat(concat_list, output, log)
        @process_runner.run(
          'ffmpeg', '-f', 'concat', '-safe', '0', '-i', concat_list,
          '-c', 'copy', '-map', '0', '-y', output,
          log_path: log
        )
      end
    end
  end
end
