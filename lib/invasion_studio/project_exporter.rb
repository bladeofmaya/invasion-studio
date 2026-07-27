module InvasionStudio
  class ProjectExporter
    def initialize(project, options = {})
      @project = project
      @options = options
      @process_runner = options[:process_runner] || ProcessRunner.new
    end

    def export_group(group_name, output_basename = nil)
      clip_paths = @project.group_clip_paths(group_name)
      raise Error, "No clips in group '#{group_name}'" if clip_paths.empty?

      output_dir = File.join(@project.folder_path, 'exports')
      FileUtils.mkdir_p(output_dir)

      output_basename = sanitize_basename(output_basename || group_name)
      spliced_path = File.join(output_dir, "#{output_basename}.mp4")
      kdenlive_path = File.join(output_dir, "#{output_basename}.kdenlive")

      splice_clips(clip_paths, spliced_path)
      metadata = gather_metadata_for(spliced_path)
      xml = KdenliveExporter.new(output_dir, @options).build_project(spliced_path, metadata)
      File.write(kdenlive_path, xml)

      [spliced_path, kdenlive_path]
    end

    private

    def sanitize_basename(value)
      basename = value.to_s.downcase.gsub(/[^a-z0-9_-]+/, '_').gsub(/\A_+|_+\z/, '')
      raise Error, 'Export filename cannot be empty' if basename.empty?

      basename
    end

    def splice_clips(clip_paths, output_path)
      concat_list_path = File.join(@project.folder_path, '.export_concat_list.txt')

      File.write(concat_list_path, clip_paths.map { |c| "file '#{c}'" }.join("\n"))

      cmd = [
        'ffmpeg', '-y',
        '-f', 'concat', '-safe', '0',
        '-i', concat_list_path,
        '-map', '0',
        '-c', 'copy',
        output_path
      ]

      puts "Splicing #{clip_paths.length} clips into #{output_path}..." unless @options[:quiet]
      unless @process_runner.run(*cmd)
        raise Error, "ffmpeg concat failed. The clips may have incompatible codecs/resolutions."
      end

      output_path
    ensure
      File.delete(concat_list_path) if File.exist?(concat_list_path)
    end

    def gather_metadata_for(path)
      video = Video.new(path)
      meta = video.metadata
      raise Error, "Could not extract metadata for #{path}" unless meta && meta[:duration] && meta[:duration] > 0
      meta
    end
  end
end
