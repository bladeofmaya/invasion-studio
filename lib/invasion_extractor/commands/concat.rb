require 'optparse'

module InvasionExtractor
  module Commands
    class Concat < Base
      def run
        parse_options!
        validate!
        execute
      end

      private

      def parse_options!
        build_parser.parse!(@argv)
      end

      def build_parser
        OptionParser.new do |opts|
          opts.banner = "Usage: bin/invasion_extractor concat [OPTIONS] FOLDER"

          opts.on("-o", "--output FILE", "Output video file path") { |v| @options[:output] = v }
          opts.on("-h", "--help", "Show this help") { puts opts; exit 0 }
        end
      end

      def validate!
        if @argv.empty?
          puts "Error: No folder specified."
          puts "Usage: bin/invasion_extractor concat [OPTIONS] FOLDER"
          exit 1
        end

        @folder = @argv.first

        unless File.directory?(@folder)
          puts "Error: #{@folder} is not a valid directory."
          exit 1
        end
      end

      def execute
        clips = discover_clips
        raise Error, "No video clips found in #{@folder}" if clips.empty?

        output_path = @options[:output] || File.join(@folder, 'combined.mp4')
        concat_list_path = File.join(@folder, '.concat_list.txt')
        metadata_path = File.join(@folder, '.chapters.txt')

        # Gather durations for chapter markers
        metadata = clips.map { |path| [path, gather_metadata_for(path)] }.to_h

        # Write concat list for ffmpeg
        File.write(concat_list_path, clips.map { |c| "file '#{c}'" }.join("\n"))

        # Write chapter metadata
        File.write(metadata_path, build_chapter_metadata(clips, metadata))

        # Run ffmpeg concat with copy codec (no re-encoding) + chapter metadata
        # -map 0 preserves all streams (video + all audio tracks)
        cmd = [
          'ffmpeg', '-y',
          '-f', 'concat', '-safe', '0',
          '-i', concat_list_path,
          '-i', metadata_path,
          '-map', '0',
          '-map_metadata', '1',
          '-c', 'copy',
          output_path
        ]

        puts "Concatenating #{clips.length} clips with ffmpeg..." unless @options[:quiet]
        system(*cmd)

        if $?.success?
          puts "Combined video with chapter markers exported to: #{output_path}" unless @options[:quiet]
        else
          puts "Error: ffmpeg concat failed. The clips may have incompatible codecs/resolutions."
          puts "Try re-encoding with: ffmpeg -f concat -safe 0 -i #{concat_list_path} -c:v libx264 -crf 18 -c:a copy #{output_path}"
          exit 1
        end
      ensure
        File.delete(concat_list_path) if File.exist?(concat_list_path)
        File.delete(metadata_path) if File.exist?(metadata_path)
      end

      def build_chapter_metadata(clips, metadata)
        lines = []
        lines << ";FFMETADATA1"
        lines << "title=Invasion Clips"
        lines << ""

        cumulative_ms = 0
        clips.each_with_index do |path, index|
          meta = metadata[path]
          duration_ms = (meta[:duration] * 1000).round
          start_ms = cumulative_ms
          end_ms = cumulative_ms + duration_ms
          basename = File.basename(path)

          lines << "[CHAPTER]"
          lines << "TIMEBASE=1/1000"
          lines << "START=#{start_ms}"
          lines << "END=#{end_ms}"
          lines << "title=#{basename}"
          lines << ""

          cumulative_ms = end_ms
        end

        lines.join("\n")
      end

      def gather_metadata_for(path)
        video = Video.new(path)
        meta = video.metadata
        raise Error, "Could not extract metadata for #{path}" unless meta && meta[:duration] && meta[:duration] > 0
        meta
      end

      VIDEO_EXTENSIONS = %w[.mp4 .mkv .avi .mov .webm .flv .wmv .m4v .mpeg .mpg].freeze

      def discover_clips
        Dir.glob(File.join(@folder, '*'))
           .select { |f| VIDEO_EXTENSIONS.include?(File.extname(f).downcase) }
           .sort
      end
    end
  end
end
