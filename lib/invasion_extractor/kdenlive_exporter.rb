require 'cgi'
require 'securerandom'
require 'json'

module InvasionExtractor
  class KdenliveExporter
    VIDEO_EXTENSIONS = %w[.mp4 .mkv .avi .mov .webm .flv .wmv .m4v .mpeg .mpg].freeze

    attr_reader :folder_path, :options

    def initialize(folder_path, options = {})
      @folder_path = folder_path
      @options = {
        transition_duration: 2.5
      }.merge(options)
    end

    def run!(output_path = default_output_path)
      clips = discover_clips
      raise Error, "No video clips found in #{@folder_path}" if clips.empty?

      # Step 1: Splice clips into a single video
      spliced_path = splice_clips(clips)

      # Step 2: Generate Kdenlive project for the spliced video
      metadata = gather_metadata_for(spliced_path)
      xml = build_xml(spliced_path, metadata)
      File.write(output_path, xml)
      output_path
    end

    def discover_clips
      Dir.glob(File.join(@folder_path, '*'))
         .select { |f| VIDEO_EXTENSIONS.include?(File.extname(f).downcase) }
         .sort
    end

    def gather_metadata_for(path)
      video = Video.new(path)
      meta = video.metadata
      raise Error, "Could not extract metadata for #{path}" unless meta && meta[:duration] && meta[:duration] > 0
      meta
    end

    private

    def default_output_path
      File.join(@folder_path, 'timeline.kdenlive')
    end

    def splice_clips(clips)
      spliced_path = File.join(@folder_path, 'combined.mp4')
      concat_list_path = File.join(@folder_path, '.concat_list.txt')

      # Write concat list
      File.write(concat_list_path, clips.map { |c| "file '#{c}'" }.join("\n"))

      # Run ffmpeg concat with all streams preserved
      cmd = [
        'ffmpeg', '-y',
        '-f', 'concat', '-safe', '0',
        '-i', concat_list_path,
        '-map', '0',
        '-c', 'copy',
        spliced_path
      ]

      puts "Splicing #{clips.length} clips into combined.mp4..." unless @options[:quiet]
      system(*cmd)

      unless $?.success?
        raise Error, "ffmpeg concat failed. The clips may have incompatible codecs/resolutions."
      end

      spliced_path
    ensure
      File.delete(concat_list_path) if File.exist?(concat_list_path)
    end

    def build_xml(video_path, meta)
      fps = meta[:fps] || 30
      duration_frames = seconds_to_frames(meta[:duration], fps)
      duration_tc = frames_to_timecode(duration_frames, fps)
      total_timecode = duration_tc
      total_frames = duration_frames
      profile_name = "#{meta[:width]}x#{meta[:height]}_#{fps}fps"

      # Generate UUIDs
      sequence_uuid = "{#{SecureRandom.uuid}}"
      doc_uuid = "{#{SecureRandom.uuid}}"
      control_uuid = "{#{SecureRandom.uuid}}"
      session_id = "{#{SecureRandom.uuid}}"
      document_id = (Time.now.to_f * 1000).to_i.to_s
      basename = File.basename(video_path)

      xml = +"<?xml version='1.0' encoding='utf-8'?>\n"
      xml << "<mlt LC_NUMERIC=\"C\" producer=\"main_bin\" root=\"#{escape_xml(File.expand_path(@folder_path))}\" version=\"7.38.0\">\n"
      xml << "  #{build_profile(meta)}\n"

      # Black producer
      xml << "  <producer id=\"producer0\" in=\"00:00:00.000\" out=\"#{total_timecode}\">\n"
      xml << "    <property name=\"length\">2147483647</property>\n"
      xml << "    <property name=\"eof\">continue</property>\n"
      xml << "    <property name=\"resource\">black</property>\n"
      xml << "    <property name=\"aspect_ratio\">1</property>\n"
      xml << "    <property name=\"mlt_service\">color</property>\n"
      xml << "    <property name=\"kdenlive:playlistid\">black_track</property>\n"
      xml << "    <property name=\"mlt_image_format\">rgba</property>\n"
      xml << "    <property name=\"set.test_audio\">0</property>\n"
      xml << "  </producer>\n"

      # Create 6 chains for the spliced video (5 timeline + 1 bin)
      6.times do |i|
        xml << "  <chain id=\"chain#{i}\" out=\"#{duration_tc}\">\n"
        xml << "    <property name=\"length\">#{duration_frames}</property>\n"
        xml << "    <property name=\"eof\">pause</property>\n"
        xml << "    <property name=\"resource\">#{escape_xml(basename)}</property>\n"
        xml << "    <property name=\"mlt_service\">avformat-novalidate</property>\n"
        xml << "    <property name=\"seekable\">1</property>\n"
        xml << "    <property name=\"kdenlive:folderid\">-1</property>\n"
        xml << "    <property name=\"kdenlive:id\">1</property>\n"
        xml << "    <property name=\"kdenlive:control_uuid\">#{control_uuid}</property>\n"
        xml << "    <property name=\"mute_on_pause\">0</property>\n"
        xml << "    <property name=\"kdenlive:clip_type\">0</property>\n"
        xml << "  </chain>\n"
      end

      # Audio track 0
      xml << "  <playlist id=\"playlist0\">\n"
      xml << "    <property name=\"kdenlive:audio_track\">1</property>\n"
      xml << "    <entry in=\"00:00:00.000\" out=\"#{duration_tc}\" producer=\"chain0\">\n"
      xml << "      <property name=\"kdenlive:id\">1</property>\n"
      xml << "    </entry>\n"
      xml << "  </playlist>\n"
      xml << "  <playlist id=\"playlist1\">\n"
      xml << "    <property name=\"kdenlive:audio_track\">1</property>\n"
      xml << "  </playlist>\n"

      # Audio track 1
      xml << "  <playlist id=\"playlist2\">\n"
      xml << "    <property name=\"kdenlive:audio_track\">1</property>\n"
      xml << "    <entry in=\"00:00:00.000\" out=\"#{duration_tc}\" producer=\"chain1\">\n"
      xml << "      <property name=\"kdenlive:id\">1</property>\n"
      xml << "    </entry>\n"
      xml << "  </playlist>\n"
      xml << "  <playlist id=\"playlist3\">\n"
      xml << "    <property name=\"kdenlive:audio_track\">1</property>\n"
      xml << "  </playlist>\n"

      # Audio track 2
      xml << "  <playlist id=\"playlist4\">\n"
      xml << "    <property name=\"kdenlive:audio_track\">1</property>\n"
      xml << "    <entry in=\"00:00:00.000\" out=\"#{duration_tc}\" producer=\"chain2\">\n"
      xml << "      <property name=\"kdenlive:id\">1</property>\n"
      xml << "    </entry>\n"
      xml << "  </playlist>\n"
      xml << "  <playlist id=\"playlist5\">\n"
      xml << "    <property name=\"kdenlive:audio_track\">1</property>\n"
      xml << "  </playlist>\n"

      # Audio track 3
      xml << "  <playlist id=\"playlist6\">\n"
      xml << "    <property name=\"kdenlive:audio_track\">1</property>\n"
      xml << "    <entry in=\"00:00:00.000\" out=\"#{duration_tc}\" producer=\"chain3\">\n"
      xml << "      <property name=\"kdenlive:id\">1</property>\n"
      xml << "    </entry>\n"
      xml << "  </playlist>\n"
      xml << "  <playlist id=\"playlist7\">\n"
      xml << "    <property name=\"kdenlive:audio_track\">1</property>\n"
      xml << "  </playlist>\n"

      # Video track 0
      xml << "  <playlist id=\"playlist8\">\n"
      xml << "    <entry in=\"00:00:00.000\" out=\"#{duration_tc}\" producer=\"chain4\">\n"
      xml << "      <property name=\"kdenlive:id\">1</property>\n"
      xml << "    </entry>\n"
      xml << "  </playlist>\n"
      xml << "  <playlist id=\"playlist9\"/>\n"

      # Video track 1 (empty)
      xml << "  <playlist id=\"playlist10\"/>\n"
      xml << "  <playlist id=\"playlist11\"/>\n"

      # Track tractors 0-3 (audio)
      4.times do |i|
        xml << "  <tractor id=\"tractor#{i}\" in=\"00:00:00.000\" out=\"#{total_timecode}\">\n"
        xml << "    <property name=\"kdenlive:audio_track\">1</property>\n"
        xml << "    <property name=\"kdenlive:trackheight\">75</property>\n"
        xml << "    <property name=\"kdenlive:timeline_active\">1</property>\n"
        xml << "    <track hide=\"video\" producer=\"playlist#{i * 2}\"/>\n"
        xml << "    <track hide=\"video\" producer=\"playlist#{i * 2 + 1}\"/>\n"
        xml << "    <filter id=\"filter#{i * 3}\">\n"
        xml << "      <property name=\"window\">75</property>\n"
        xml << "      <property name=\"max_gain\">20dB</property>\n"
        xml << "      <property name=\"channel_mask\">-1</property>\n"
        xml << "      <property name=\"mlt_service\">volume</property>\n"
        xml << "      <property name=\"internal_added\">237</property>\n"
        xml << "      <property name=\"disable\">1</property>\n"
        xml << "    </filter>\n"
        xml << "    <filter id=\"filter#{i * 3 + 1}\">\n"
        xml << "      <property name=\"channel\">-1</property>\n"
        xml << "      <property name=\"mlt_service\">panner</property>\n"
        xml << "      <property name=\"internal_added\">237</property>\n"
        xml << "      <property name=\"start\">0.5</property>\n"
        xml << "      <property name=\"disable\">1</property>\n"
        xml << "    </filter>\n"
        xml << "    <filter id=\"filter#{i * 3 + 2}\">\n"
        xml << "      <property name=\"iec_scale\">0</property>\n"
        xml << "      <property name=\"mlt_service\">audiolevel</property>\n"
        xml << "      <property name=\"internal_added\">237</property>\n"
        xml << "      <property name=\"dbpeak\">1</property>\n"
        xml << "      <property name=\"disable\">1</property>\n"
        xml << "    </filter>\n"
        xml << "  </tractor>\n"
      end

      # Video track tractors 4-5
      xml << "  <tractor id=\"tractor4\" in=\"00:00:00.000\" out=\"#{total_timecode}\">\n"
      xml << "    <property name=\"kdenlive:trackheight\">75</property>\n"
      xml << "    <property name=\"kdenlive:timeline_active\">1</property>\n"
      xml << "    <track hide=\"audio\" producer=\"playlist8\"/>\n"
      xml << "    <track hide=\"audio\" producer=\"playlist9\"/>\n"
      xml << "  </tractor>\n"

      xml << "  <tractor id=\"tractor5\" in=\"00:00:00.000\">\n"
      xml << "    <property name=\"kdenlive:trackheight\">75</property>\n"
      xml << "    <property name=\"kdenlive:timeline_active\">1</property>\n"
      xml << "    <track hide=\"audio\" producer=\"playlist10\"/>\n"
      xml << "    <track hide=\"audio\" producer=\"playlist11\"/>\n"
      xml << "  </tractor>\n"

      # Sequence tractor
      xml << "  <tractor id=\"#{sequence_uuid}\" in=\"00:00:00.000\" out=\"#{total_timecode}\">\n"
      xml << "    <property name=\"kdenlive:uuid\">#{sequence_uuid}</property>\n"
      xml << "    <property name=\"kdenlive:clipname\">Sequence 1</property>\n"
      xml << "    <property name=\"kdenlive:sequenceproperties.hasAudio\">1</property>\n"
      xml << "    <property name=\"kdenlive:sequenceproperties.hasVideo\">1</property>\n"
      xml << "    <property name=\"kdenlive:sequenceproperties.activeTrack\">4</property>\n"
      xml << "    <property name=\"kdenlive:sequenceproperties.tracksCount\">6</property>\n"
      xml << "    <property name=\"kdenlive:sequenceproperties.documentuuid\">#{sequence_uuid}</property>\n"
      xml << "    <property name=\"kdenlive:control_uuid\">#{sequence_uuid}</property>\n"
      xml << "    <property name=\"kdenlive:duration\">#{frames_to_timecode(total_frames + 1, fps)}</property>\n"
      xml << "    <property name=\"kdenlive:maxduration\">#{total_frames}</property>\n"
      xml << "    <property name=\"kdenlive:producer_type\">17</property>\n"
      xml << "    <property name=\"kdenlive:id\">3</property>\n"
      xml << "    <property name=\"kdenlive:clip_type\">0</property>\n"
      xml << "    <property name=\"kdenlive:file_size\">0</property>\n"
      xml << "    <property name=\"kdenlive:folderid\">2</property>\n"
      xml << "    <property name=\"kdenlive:sequenceproperties.audioTarget\">1</property>\n"
      xml << "    <property name=\"kdenlive:sequenceproperties.videoTarget\">2</property>\n"
      xml << "    <property name=\"kdenlive:sequenceproperties.tracks\">4</property>\n"

      # Groups for single clip
      group = {
        "children" => [
          {"data" => "0:0:-1", "leaf" => "clip", "type" => "Leaf"},
          {"data" => "1:0:-1", "leaf" => "clip", "type" => "Leaf"},
          {"data" => "2:0:-1", "leaf" => "clip", "type" => "Leaf"},
          {"data" => "3:0:-1", "leaf" => "clip", "type" => "Leaf"},
          {"data" => "4:0:-1", "leaf" => "clip", "type" => "Leaf"}
        ],
        "type" => "AVSplit"
      }
      xml << "    <property name=\"kdenlive:sequenceproperties.groups\">#{JSON.pretty_generate([group])}\n"
      xml << "</property>\n"
      xml << "    <property name=\"kdenlive:sequenceproperties.guides\">[\n]\n"
      xml << "</property>\n"

      # Tracks
      xml << "    <track producer=\"producer0\"/>\n"
      6.times do |i|
        xml << "    <track producer=\"tractor#{i}\"/>\n"
      end

      # Mix transitions for audio tracks 1-4
      4.times do |i|
        xml << "    <transition id=\"transition#{i}\">\n"
        xml << "      <property name=\"a_track\">0</property>\n"
        xml << "      <property name=\"b_track\">#{i + 1}</property>\n"
        xml << "      <property name=\"mlt_service\">mix</property>\n"
        xml << "      <property name=\"kdenlive_id\">mix</property>\n"
        xml << "      <property name=\"internal_added\">237</property>\n"
        xml << "      <property name=\"always_active\">1</property>\n"
        xml << "      <property name=\"accepts_blanks\">1</property>\n"
        xml << "      <property name=\"sum\">1</property>\n"
        xml << "    </transition>\n"
      end

      # qtblend transitions for video tracks 5-6
      2.times do |i|
        xml << "    <transition id=\"transition#{i + 4}\">\n"
        xml << "      <property name=\"a_track\">0</property>\n"
        xml << "      <property name=\"b_track\">#{i + 5}</property>\n"
        xml << "      <property name=\"compositing\">0</property>\n"
        xml << "      <property name=\"distort\">0</property>\n"
        xml << "      <property name=\"rotate_center\">0</property>\n"
        xml << "      <property name=\"mlt_service\">qtblend</property>\n"
        xml << "      <property name=\"kdenlive_id\">qtblend</property>\n"
        xml << "      <property name=\"internal_added\">237</property>\n"
        xml << "      <property name=\"always_active\">1</property>\n"
        xml << "    </transition>\n"
      end

      # Sequence filters
      xml << "    <filter id=\"filter12\">\n"
      xml << "      <property name=\"window\">75</property>\n"
      xml << "      <property name=\"max_gain\">20dB</property>\n"
      xml << "      <property name=\"channel_mask\">-1</property>\n"
      xml << "      <property name=\"mlt_service\">volume</property>\n"
      xml << "      <property name=\"internal_added\">237</property>\n"
      xml << "      <property name=\"disable\">1</property>\n"
      xml << "    </filter>\n"
      xml << "    <filter id=\"filter13\">\n"
      xml << "      <property name=\"channel\">-1</property>\n"
      xml << "      <property name=\"mlt_service\">panner</property>\n"
      xml << "      <property name=\"internal_added\">237</property>\n"
      xml << "      <property name=\"start\">0.5</property>\n"
      xml << "      <property name=\"disable\">1</property>\n"
      xml << "    </filter>\n"
      xml << "  </tractor>\n"

      # Main bin
      xml << "  <playlist id=\"main_bin\">\n"
      xml << "    <property name=\"kdenlive:folder.-1.2\">Sequences</property>\n"
      xml << "    <property name=\"kdenlive:sequenceFolder\">2</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.audioChannels\">2</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.binsort\">0</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.browserurl\"/>\n"
      xml << "    <property name=\"kdenlive:docproperties.documentid\">#{document_id}</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.enableTimelineZone\">0</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.enableexternalproxy\">0</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.enableproxy\">0</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.externalproxyparams\"/>\n"
      xml << "    <property name=\"kdenlive:docproperties.generateimageproxy\">0</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.generateproxy\">0</property>\n"

      # guidesCategories JSON
      guides = [
        {"color" => "#9b59b6", "comment" => "Category 1", "index" => 0},
        {"color" => "#3daee9", "comment" => "Category 2", "index" => 1},
        {"color" => "#1abc9c", "comment" => "Category 3", "index" => 2},
        {"color" => "#1cdc9a", "comment" => "Category 4", "index" => 3},
        {"color" => "#c9ce3b", "comment" => "Category 5", "index" => 4},
        {"color" => "#fdbc4b", "comment" => "Category 6", "index" => 5},
        {"color" => "#f39c1f", "comment" => "Category 7", "index" => 6},
        {"color" => "#f47750", "comment" => "Category 8", "index" => 7},
        {"color" => "#da4453", "comment" => "Category 9", "index" => 8}
      ]
      xml << "    <property name=\"kdenlive:docproperties.guidesCategories\">#{JSON.pretty_generate(guides)}\n"
      xml << "</property>\n"

      xml << "    <property name=\"kdenlive:docproperties.kdenliveversion\">26.04.1</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.previewextension\"/>\n"
      xml << "    <property name=\"kdenlive:docproperties.previewparameters\"/>\n"
      xml << "    <property name=\"kdenlive:docproperties.profile\">#{profile_name}</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.proxyextension\"/>\n"
      xml << "    <property name=\"kdenlive:docproperties.proxyimageminsize\">2000</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.proxyimagesize\">800</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.proxyminsize\">1000</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.proxyparams\"/>\n"
      xml << "    <property name=\"kdenlive:docproperties.proxyresize\">640</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.seekOffset\">30000</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.sessionid\">#{session_id}</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.uuid\">#{doc_uuid}</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.version\">1.1</property>\n"
      xml << "    <property name=\"kdenlive:expandedFolders\"/>\n"
      xml << "    <property name=\"kdenlive:binZoom\">4</property>\n"
      xml << "    <property name=\"kdenlive:extraBins\">project_bin:-1:0</property>\n"
      xml << "    <property name=\"kdenlive:documentnotes\"/>\n"
      xml << "    <property name=\"kdenlive:documentnotesversion\">2</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.opensequences\">#{sequence_uuid}</property>\n"
      xml << "    <property name=\"kdenlive:docproperties.activetimeline\">#{sequence_uuid}</property>\n"
      xml << "    <property name=\"xml_retain\">1</property>\n"

      # Sequence entry
      xml << "    <entry in=\"00:00:00.000\" out=\"00:00:00.000\" producer=\"#{sequence_uuid}\"/>\n"

      # Bin clip entry
      xml << "    <entry in=\"00:00:00.000\" out=\"#{duration_tc}\" producer=\"chain5\"/>\n"
      xml << "  </playlist>\n"

      # Project tractor
      xml << "  <tractor id=\"tractor_project\" in=\"00:00:00.000\" out=\"#{total_timecode}\">\n"
      xml << "    <property name=\"kdenlive:projectTractor\">1</property>\n"
      xml << "    <track in=\"00:00:00.000\" out=\"#{total_timecode}\" producer=\"#{sequence_uuid}\"/>\n"
      xml << "  </tractor>\n"

      xml << "</mlt>\n"
      xml
    end

    def build_profile(meta)
      width = meta[:width] || 1920
      height = meta[:height] || 1080
      fps_num = meta[:fps] || 30
      fps_den = 1

      aspect_num = width
      aspect_den = height
      gcd_val = aspect_num.gcd(aspect_den)
      aspect_num /= gcd_val
      aspect_den /= gcd_val

      %Q{<profile description="Auto #{width}x#{height} #{fps_num} fps" width="#{width}" height="#{height}" progressive="1" sample_aspect_num="1" sample_aspect_den="1" display_aspect_num="#{aspect_num}" display_aspect_den="#{aspect_den}" frame_rate_num="#{fps_num}" frame_rate_den="#{fps_den}" colorspace="709"/>}
    end

    def seconds_to_frames(seconds, fps)
      (seconds * fps).round
    end

    def frames_to_timecode(frames, fps)
      return "00:00:00.000" if frames <= 0
      seconds = frames.to_f / fps
      hours = (seconds / 3600).to_i
      minutes = ((seconds % 3600) / 60).to_i
      secs = (seconds % 60).to_i
      millis = ((seconds % 1) * 1000).round
      format("%02d:%02d:%02d.%03d", hours, minutes, secs, millis)
    end

    def escape_xml(text)
      CGI.escapeHTML(text)
    end
  end
end
