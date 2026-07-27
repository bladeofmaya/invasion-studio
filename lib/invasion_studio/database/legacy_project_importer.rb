# frozen_string_literal: true

require 'json'

module InvasionStudio
  module Database
    class LegacyProjectImporter
      LEGACY_PROJECT_FILE = 'project.json'
      IMPORTED_KEY = 'legacy_project_imported_at'

      def initialize(database, folder_path, clock: -> { Time.now.utc })
        @database = database
        @folder_path = File.expand_path(folder_path)
        @clock = clock
      end

      def run_if_needed
        return false unless legacy_file_exists?
        return false if already_imported?

        data = read_legacy_data
        return false unless data

        import(data)
        mark_imported
        true
      end

      private

      def legacy_file_exists?
        File.exist?(File.join(@folder_path, LEGACY_PROJECT_FILE))
      end

      def already_imported?
        project_metadata_dataset.where(key: IMPORTED_KEY).count.positive?
      end

      def read_legacy_data
        path = File.join(@folder_path, LEGACY_PROJECT_FILE)
        JSON.parse(File.read(path))
      rescue JSON::ParserError
        nil
      end

      def import(data)
        @database.transaction do
          clip_ids = import_clips(data['clips'] || [])
          import_groups(data['groups'] || [], clip_ids)
        end
      end

      def import_clips(clips)
        clip_ids = {}
        clips.each do |clip|
          id = clip.fetch('id') { File.basename(clip['filename'].to_s, '.*') }
          next if id.nil? || id.empty?

          timestamp = current_timestamp
          clip_ids[id] = true
          clip_dataset.insert(
            id: id,
            title: normalize_title(clip['title']),
            note: clip.fetch('note', '').to_s,
            rating: Integer(clip.fetch('rating', 0), exception: false) || 0,
            result: normalize_result(clip['result']),
            source_kind: 'external',
            original_filename: clip['filename'].to_s,
            storage_path: relative_path(clip['path']),
            duration: nil,
            filesize: nil,
            width: nil,
            height: nil,
            fps: nil,
            video_codec: nil,
            audio_codec: nil,
            thumbnail_path: nil,
            deleted_at: clip['deleted'] ? timestamp : nil,
            deleted_path: clip['deleted'] ? clip['trash_path'] : nil,
            created_at: timestamp,
            updated_at: timestamp
          )

          import_cuts(id, clip['cuts'])
        end
        clip_ids
      end

      def import_cuts(clip_id, cuts)
        return unless cuts.is_a?(Array)

        cuts.each_with_index do |cut, index|
          start_time = Float(cut['start'] || cut[:start], exception: false)
          end_time = Float(cut['end'] || cut[:end], exception: false)
          next unless start_time&.finite? && end_time&.finite?

          timestamp = current_timestamp
          cuts_dataset.insert(
            clip_id: clip_id,
            position: index,
            start: start_time,
            end: end_time,
            created_at: timestamp,
            updated_at: timestamp
          )
        end
      end

      def import_groups(groups, clip_ids)
        groups.each_with_index do |group, index|
          name = group['name'].to_s
          next if name.empty?

          timestamp = current_timestamp
          group_id = groups_dataset.insert(
            name: name,
            position: index,
            created_at: timestamp,
            updated_at: timestamp
          )

          Array(group['clip_ids']).each_with_index do |clip_id, position|
            next unless clip_ids.key?(clip_id)

            group_clips_dataset.insert(
              compilation_id: group_id,
              clip_id: clip_id,
              position: position,
              created_at: timestamp
            )
          end
        end
      end

      def mark_imported
        timestamp = current_timestamp
        project_metadata_dataset.insert_ignore.insert(
          key: IMPORTED_KEY,
          value: timestamp,
          created_at: timestamp,
          updated_at: timestamp
        )
      end

      def normalize_title(title)
        stripped = title.to_s.strip
        stripped.empty? ? nil : stripped
      end

      def normalize_result(result)
        return nil if result.nil?
        return result if %w[win loss dc].include?(result.to_s)

        nil
      end

      def relative_path(path)
        return nil if path.nil? || path.empty?

        absolute = File.absolute_path(path) == path
        return path unless absolute

        path.delete_prefix("#{@folder_path}#{File::SEPARATOR}")
      end

      def clip_dataset
        @database[:clips]
      end

      def cuts_dataset
        @database[:cuts]
      end

      def groups_dataset
        @database[:compilations]
      end

      def group_clips_dataset
        @database[:compilation_clips]
      end

      def project_metadata_dataset
        @database[:project_metadata]
      end

      def current_timestamp
        @clock.call.iso8601
      end
    end
  end
end
