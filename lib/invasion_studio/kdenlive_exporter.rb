module InvasionStudio
  class KdenliveExporter
    attr_reader :folder_path, :options

    def initialize(folder_path, options = {})
      @folder_path = folder_path
      @options = {
        # Kdenlive projects stay pinned to 2K; Kdenlive scales source clips.
        profile_width: 2560,
        profile_height: 1440
      }.merge(options)
      @process_runner = @options[:process_runner] || ProcessRunner.new
      @document_builder = @options[:document_builder] || build_document_builder
    end

    def run!(output_path = default_output_path)
      clips = discover_clips
      raise Error, "No video clips found in #{@folder_path}" if clips.empty?

      spliced_path = splice_clips(clips)
      File.write(output_path, build_project(spliced_path, gather_metadata_for(spliced_path)))
      output_path
    end

    def discover_clips
      MediaFiles.discover(@folder_path)
    end

    def gather_metadata_for(path)
      metadata = Video.new(path).metadata
      return metadata if metadata && metadata[:duration] && metadata[:duration].positive?

      raise Error, "Could not extract metadata for #{path}"
    end

    def build_project(video_path, metadata, chapters: [])
      @document_builder.build(video_path, metadata, chapters: chapters)
    end

    private

    def build_document_builder
      Kdenlive::DocumentBuilder.new(
        folder_path: @folder_path,
        width: @options[:profile_width],
        height: @options[:profile_height]
      )
    end

    def default_output_path
      File.join(@folder_path, 'timeline.kdenlive')
    end

    def splice_clips(clips)
      spliced_path = File.join(@folder_path, 'combined.mp4')
      concat_list_path = File.join(@folder_path, '.concat_list.txt')
      File.write(concat_list_path, clips.map { |clip| "file '#{clip}'" }.join("\n"))

      command = [
        Executables.ffmpeg, '-y',
        '-f', 'concat', '-safe', '0',
        '-i', concat_list_path,
        '-map', '0',
        '-c', 'copy',
        spliced_path
      ]

      puts "Splicing #{clips.length} clips into combined.mp4..." unless @options[:quiet]
      runner_options = @options[:quiet] ? { log_path: File::NULL } : {}
      return spliced_path if @process_runner.run(*command, **runner_options)

      raise Error, 'ffmpeg concat failed. The clips may have incompatible codecs/resolutions.'
    ensure
      File.delete(concat_list_path) if concat_list_path && File.exist?(concat_list_path)
    end

    # Kept as private compatibility helpers for callers that introspect the
    # exporter. Document generation now owns timecode conversion in BuildContext.
    def seconds_to_frames(seconds, fps)
      (seconds * fps).round
    end

    def frames_to_timecode(frames, fps)
      return '00:00:00.000' if frames <= 0

      seconds = frames.to_f / fps
      hours = (seconds / 3600).to_i
      minutes = ((seconds % 3600) / 60).to_i
      secs = (seconds % 60).to_i
      millis = ((seconds % 1) * 1000).round
      format('%02d:%02d:%02d.%03d', hours, minutes, secs, millis)
    end
  end
end
