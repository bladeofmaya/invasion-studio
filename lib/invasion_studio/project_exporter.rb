module InvasionStudio
  class ProjectExporter
    def initialize(project, options = {})
      @project = project
      @options = options
      @process_runner = options[:process_runner] || ProcessRunner.new
      @metadata_probe = options[:metadata_probe] || ->(path) { Video.new(path).metadata }
    end

    def export_group(group_name, output_basename = nil)
      clips = exportable_clips(group_name)
      raise Error, "No clips in group '#{group_name}'" if clips.empty?

      output_dir = File.join(@project.folder_path, 'exports')
      FileUtils.mkdir_p(output_dir)

      output_basename = sanitize_basename(output_basename || group_name)
      spliced_path = File.join(output_dir, "#{output_basename}.mp4")
      kdenlive_path = File.join(output_dir, "#{output_basename}.kdenlive")
      chapters = build_chapters(clips)

      splice_clips(clips.map { |clip| clip.fetch('resolved_path') }, spliced_path, chapters)
      metadata = gather_metadata_for(spliced_path)
      xml = KdenliveExporter.new(output_dir, @options)
                            .build_project(spliced_path, metadata, chapters: chapters)
      File.write(kdenlive_path, xml)

      [spliced_path, kdenlive_path]
    end

    private

    def sanitize_basename(value)
      basename = value.to_s.downcase.gsub(/[^a-z0-9_-]+/, '_').gsub(/\A_+|_+\z/, '')
      raise Error, 'Export filename cannot be empty' if basename.empty?

      basename
    end

    def exportable_clips(group_name)
      @project.group_clips(group_name).filter_map do |clip|
        path = @project.resolve_clip_path(clip)
        clip.merge('resolved_path' => path) if path
      end
    end

    def build_chapters(clips)
      position = 0.0
      clips.map do |clip|
        duration = clip_duration(clip)
        chapter = {
          title: chapter_title(clip),
          start_time: position,
          end_time: position + duration
        }
        position = chapter[:end_time]
        chapter
      end
    end

    def chapter_title(clip)
      title = clip['title'].to_s.strip
      title.empty? ? clip['filename'].to_s : title
    end

    def clip_duration(clip)
      duration = clip['duration'].to_f
      return duration if duration.positive?

      metadata = @metadata_probe.call(clip['resolved_path'])
      duration = metadata && metadata[:duration].to_f
      return duration if duration&.positive?

      raise Error, "Could not determine duration for #{clip['filename']}"
    end

    def splice_clips(clip_paths, output_path, chapters)
      concat_list_path = File.join(@project.folder_path, '.export_concat_list.txt')
      chapter_metadata_path = File.join(@project.folder_path, '.export_chapters.txt')

      File.write(concat_list_path, clip_paths.map { |c| "file '#{c}'" }.join("\n"))
      File.write(chapter_metadata_path, build_chapter_metadata(chapters))

      cmd = [
        'ffmpeg', '-y',
        '-f', 'concat', '-safe', '0',
        '-i', concat_list_path,
        '-i', chapter_metadata_path,
        '-map', '0',
        '-map_metadata', '1',
        '-map_chapters', '1',
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
      File.delete(chapter_metadata_path) if chapter_metadata_path && File.exist?(chapter_metadata_path)
    end

    def build_chapter_metadata(chapters)
      lines = [';FFMETADATA1', 'title=Invasion Studio Compilation', '']
      chapters.each do |chapter|
        lines.concat([
          '[CHAPTER]',
          'TIMEBASE=1/1000',
          "START=#{(chapter[:start_time] * 1000).round}",
          "END=#{(chapter[:end_time] * 1000).round}",
          "title=#{escape_ffmetadata(chapter[:title])}",
          ''
        ])
      end
      lines.join("\n")
    end

    def escape_ffmetadata(value)
      value.to_s.gsub(/[\r\n]+/, ' ')
           .gsub('\\') { '\\\\' }
           .gsub(/([=;#])/, '\\\\\1')
    end

    def gather_metadata_for(path)
      meta = @metadata_probe.call(path)
      raise Error, "Could not extract metadata for #{path}" unless meta && meta[:duration] && meta[:duration] > 0
      meta
    end
  end
end
