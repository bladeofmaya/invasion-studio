# frozen_string_literal: true

require 'securerandom'

module InvasionStudio
  class ClipFinalizer
    def initialize(folder_path, catalog, process_runner: ProcessRunner.new,
                   metadata_probe: ->(path) { Video.new(path).metadata },
                   clock: -> { Time.now }, random_suffix: -> { SecureRandom.hex(4) })
      @folder_path = File.expand_path(folder_path)
      @catalog = catalog
      @process_runner = process_runner
      @metadata_probe = metadata_probe
      @clock = clock
      @random_suffix = random_suffix
    end

    def finalize(clip, media_operation: nil)
      plan = CutPlan.build(clip['cuts'])
      return false unless plan && plan.cuts.any?

      source_path = @catalog.path_for(clip)
      return false unless source_path && File.exist?(source_path)

      metadata = @metadata_probe.call(source_path)
      duration = metadata && metadata[:duration]
      keep_segments = plan.keep_segments(duration)
      return false if keep_segments.empty?

      backup_path = backup(source_path, clip['filename'])
      temporary_dir = Dir.mktmpdir
      output_path = File.join(temporary_dir, "finalized#{File.extname(clip['filename'])}")
      operation = media_operation || method(:run_ffmpeg)
      success = operation.call(backup_path, keep_segments, output_path)
      return false unless success && valid_output?(output_path)

      FileUtils.mv(output_path, source_path)
      clip['cuts'] = []
      true
    ensure
      FileUtils.rm_rf(temporary_dir) if temporary_dir
    end

    private

    def backup(source_path, filename)
      backup_dir = File.join(@folder_path, '.backup')
      FileUtils.mkdir_p(backup_dir)
      backup_path = unique_destination(backup_dir, filename)
      FileUtils.cp(source_path, backup_path)
      backup_path
    end

    def unique_destination(directory, filename)
      safe_filename = File.basename(filename.to_s)
      candidate = File.join(directory, safe_filename)
      return candidate unless File.exist?(candidate)

      extension = File.extname(safe_filename)
      basename = File.basename(safe_filename, extension)
      File.join(directory, "#{basename}_#{@clock.call.to_i}_#{@random_suffix.call}#{extension}")
    end

    def valid_output?(path)
      File.exist?(path) && File.size(path).positive?
    end

    def run_ffmpeg(source_path, keep_segments, output_path)
      return cut_segment(source_path, keep_segments.first, output_path) if keep_segments.one?

      cut_and_concat_segments(source_path, keep_segments, output_path)
    end

    def cut_segment(source_path, segment, output_path)
      @process_runner.run(
        'ffmpeg', '-y',
        '-ss', segment[:start].to_s,
        '-i', source_path,
        '-t', (segment[:end] - segment[:start]).to_s,
        '-c', 'copy', '-map', '0',
        '-avoid_negative_ts', 'make_zero',
        output_path
      )
    end

    def cut_and_concat_segments(source_path, keep_segments, output_path)
      segment_files = keep_segments.each_with_index.filter_map do |segment, index|
        segment_path = File.join(File.dirname(output_path), "seg_#{index}.mp4")
        next unless cut_segment(source_path, segment, segment_path)
        next unless valid_output?(segment_path)

        metadata = @metadata_probe.call(segment_path)
        segment_path if metadata && metadata[:duration] && metadata[:duration] > 0.1
      end
      return false if segment_files.empty?

      if segment_files.one?
        FileUtils.cp(segment_files.first, output_path)
        return valid_output?(output_path)
      end

      concat_list = File.join(File.dirname(output_path), 'concat_list.txt')
      File.write(concat_list, segment_files.map { |path| "file '#{path}'" }.join("\n"))
      @process_runner.run(
        'ffmpeg', '-y', '-f', 'concat', '-safe', '0', '-i', concat_list,
        '-map', '0', '-c', 'copy', output_path
      )
    end
  end
end
