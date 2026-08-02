# frozen_string_literal: true

module InvasionStudio
  module Database
    class ClipRepository
      VALID_RESULTS = %w[win loss dc].freeze
      DEFAULT_RESULT = nil
      MAX_RATING = 5
      MIN_RATING = 0

      def initialize(database, storage)
        @database = database
        @storage = storage
      end

      def all
        active_records.map { |record| clip_attributes(record) }
      end

      # Highest sequence number used by any registered clip — including
      # trashed clips and non-mp4 files — parsed from the stored filename
      # (e.g. clips/clip_00021.mkv -> 21). The number allocator must never
      # re-mint these even when the file is not in clips/ right now.
      def highest_clip_number
        clip_dataset.select_map(:storage_path).filter_map do |path|
          File.basename(path.to_s)[/_(\d+)\.[^.]+\z/, 1]&.to_i
        end.max || 0
      end

      def active
        all.reject { |clip| clip['deleted'] }
      end

      def deleted
        all.select { |clip| clip['deleted'] }
      end

      def find(id)
        record = clip_dataset.where(id: id).first
        return nil unless record

        clip_attributes(record)
      end

      def exist?(id)
        clip_dataset.where(id: id).count.positive?
      end

      def create(attributes)
        timestamp = current_timestamp
        row = build_record(attributes, timestamp)
        record = @database.transaction(mode: :immediate) do
          existing = clip_dataset.where(storage_path: row[:storage_path]).first
          next existing if existing

          clip_dataset.insert(row)
          clip_dataset.where(id: row[:id]).first
        end
        clip_attributes(record)
      end

      def upsert_by_path(attributes)
        timestamp = current_timestamp
        row = build_record(attributes, timestamp)
        record = @database.transaction(mode: :immediate) do
          existing = clip_dataset.where(storage_path: row[:storage_path]).first
          if existing
            updates = row.reject { |key, _value| %i[id created_at title note rating result].include?(key) }
            clip_dataset.where(id: existing[:id]).update(updates)
            clip_dataset.where(id: existing[:id]).first
          else
            clip_dataset.insert(row)
            clip_dataset.where(id: row[:id]).first
          end
        end
        clip_attributes(record)
      end

      def build_record(attributes, timestamp)
        {
          id: attributes.fetch('id'),
          title: normalize_title(attributes['title']),
          note: attributes.fetch('note', '').to_s,
          rating: normalize_rating(attributes['rating']),
          result: normalize_result(attributes['result']),
          source_kind: attributes.fetch('source_kind', 'uploaded'),
          source_video: attributes['source_video'],
          original_filename: attributes.fetch('filename'),
          storage_path: attributes.fetch('path'),
          duration: attributes['duration'],
          filesize: attributes['filesize'],
          width: attributes['width'],
          height: attributes['height'],
          fps: attributes['fps'],
          video_codec: attributes['video_codec'],
          audio_codec: attributes['audio_codec'],
          thumbnail_path: attributes['thumbnail_path'],
          deleted_at: nil,
          deleted_path: nil,
          created_at: timestamp,
          updated_at: timestamp
        }
      end

      def update(id, attributes)
        updates = {}
        updates[:title] = normalize_title(attributes['title']) if attributes.key?('title')
        updates[:note] = attributes['note'].to_s if attributes.key?('note')
        updates[:rating] = normalize_rating(attributes['rating']) if attributes.key?('rating')
        updates[:result] = normalize_result(attributes['result']) if attributes.key?('result')
        updates[:storage_path] = attributes['path'] if attributes.key?('path')
        updates[:thumbnail_path] = attributes['thumbnail_path'] if attributes.key?('thumbnail_path')
        updates[:source_kind] = attributes['source_kind'] if attributes.key?('source_kind')
        updates[:source_video] = attributes['source_video'] if attributes.key?('source_video')
        %w[duration filesize width height fps video_codec audio_codec].each do |field|
          updates[field.to_sym] = attributes[field] if attributes.key?(field)
        end
        updates[:updated_at] = current_timestamp

        return false if updates.empty?

        clip_dataset.where(id: id).update(updates)
        true
      end

      def update_cuts(id, cuts)
        plan = CutPlan.build(cuts)
        return false unless plan

        @database.transaction do
          cuts_dataset.where(clip_id: id).delete
          plan.cuts.each_with_index do |cut, index|
            cuts_dataset.insert(
              clip_id: id,
              start: cut['start'].to_f,
              end: cut['end'].to_f,
              created_at: current_timestamp,
              updated_at: current_timestamp,
              position: index
            )
          end
          clip_dataset.where(id: id).update(updated_at: current_timestamp)
        end
        true
      end

      def mark_deleted(id, deleted_path: nil)
        clip_dataset.where(id: id).update(
          deleted_at: current_timestamp,
          deleted_path: deleted_path,
          updated_at: current_timestamp
        )
        true
      end

      def mark_restored(id)
        clip_dataset.where(id: id).update(
          deleted_at: nil,
          deleted_path: nil,
          updated_at: current_timestamp
        )
        true
      end

      def remove_missing
        missing_ids = active_records.filter_map do |record|
          record_id = record[:id]
          path_exists = @storage.exist?(record[:storage_path])
          deleted_path_exists = record[:deleted_path] && @storage.exist?(record[:deleted_path])
          record_id unless path_exists || deleted_path_exists
        end

        return 0 if missing_ids.empty?

        clips_with_groups = group_clips_dataset.where(clip_id: missing_ids).select_map(:clip_id)
        @database.transaction do
          group_clips_dataset.where(clip_id: missing_ids).delete
          cuts_dataset.where(clip_id: missing_ids).delete
          clip_tags_dataset.where(clip_id: missing_ids).delete
          clip_dataset.where(id: missing_ids).delete
        end
        missing_ids.length
      end

      def purge(id)
        @database.transaction do
          group_clips_dataset.where(clip_id: id).delete
          cuts_dataset.where(clip_id: id).delete
          clip_tags_dataset.where(clip_id: id).delete
          clip_dataset.where(id: id).delete
        end
        true
      end

      def path_for(clip)
        @storage.resolve(clip['path'])
      end

      def resolve(path)
        @storage.resolve(path)
      end

      def relative_path(path)
        @storage.relative_path(path)
      end

      def tags_for(id)
        tags_dataset.join(:clip_tags, tag_id: :id)
                    .where(Sequel[:clip_tags][:clip_id] => id)
                    .select(Sequel[:tags][:name])
                    .order(Sequel[:tags][:name])
                    .map { |tag| tag[:name] }
      end

      def tag_ids_for(id)
        clip_tags_dataset.where(clip_id: id).select_map(:tag_id)
      end

      def add_tag(id, tag_id)
        return false unless exist?(id)

        clip_tags_dataset.insert_ignore.insert(
          clip_id: id,
          tag_id: tag_id,
          created_at: current_timestamp
        )
        true
      end

      def remove_tag(id, tag_id)
        clip_tags_dataset.where(clip_id: id, tag_id: tag_id).delete
        true
      end

      private

      def clip_dataset
        @database[:clips]
      end

      def cuts_dataset
        @database[:cuts]
      end

      def group_clips_dataset
        @database[:compilation_clips]
      end

      def clip_tags_dataset
        @database[:clip_tags]
      end

      def tags_dataset
        @database[:tags]
      end

      def active_records
        clip_dataset.order(:created_at, :id).all
      end

      def clip_attributes(record)
        cuts = cuts_dataset.where(clip_id: record[:id])
                           .order(:position, :start)
                           .map { |cut| { 'start' => cut[:start], 'end' => cut[:end] } }
        {
          'id' => record[:id],
          'filename' => record[:original_filename],
          'path' => record[:storage_path],
          'title' => record[:title],
          'note' => record[:note],
          'rating' => record[:rating],
          'result' => record[:result],
          'source_kind' => record[:source_kind],
          'source_video' => record[:source_video],
          'duration' => record[:duration],
          'filesize' => record[:filesize],
          'width' => record[:width],
          'height' => record[:height],
          'fps' => record[:fps],
          'video_codec' => record[:video_codec],
          'audio_codec' => record[:audio_codec],
          'thumbnail_path' => record[:thumbnail_path],
          'cuts' => cuts,
          'deleted' => !record[:deleted_at].nil?,
          'trash_path' => record[:deleted_path],
          'created_at' => record[:created_at],
          'updated_at' => record[:updated_at]
        }
      end

      def normalize_title(title)
        stripped = title.to_s.strip
        stripped.empty? ? nil : stripped
      end

      def normalize_rating(rating)
        return MIN_RATING if rating.nil?

        rating.to_i.clamp(MIN_RATING, MAX_RATING)
      end

      def normalize_result(result)
        return DEFAULT_RESULT if result.nil?

        VALID_RESULTS.include?(result.to_s) ? result.to_s : DEFAULT_RESULT
      end

      def current_timestamp
        Time.now.utc.iso8601
      end
    end
  end
end
