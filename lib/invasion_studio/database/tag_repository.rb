# frozen_string_literal: true

module InvasionStudio
  module Database
    class TagRepository
      def initialize(database, clip_repository:)
        @database = database
        @clip_repository = clip_repository
      end

      def all
        tags_dataset.order(:name).select_map(:name)
      end

      def find_or_create(name)
        name = normalize_name(name)
        return nil if name.empty?

        tag = tags_dataset.where(name: name).first
        return tag[:id] if tag

        tags_dataset.insert(name: name, created_at: current_timestamp)
      end

      def find_id(name)
        tag = tags_dataset.where(name: normalize_name(name)).first
        tag&.fetch(:id)
      end

      def delete_unused
        used_ids = clip_tags_dataset.select_group(:tag_id).select_map(:tag_id)
        tags_dataset.exclude(id: used_ids).delete
      end

      def clips_for(name)
        tag_id = find_id(name)
        return [] unless tag_id

        clip_ids = clip_tags_dataset.where(tag_id: tag_id).select_map(:clip_id)
        clip_ids.filter_map { |id| @clip_repository.find(id) }
                .reject { |clip| clip['deleted'] }
      end

      def add_to_clip(clip_id, name)
        tag_id = find_or_create(name)
        return false unless tag_id

        @clip_repository.add_tag(clip_id, tag_id)
      end

      def remove_from_clip(clip_id, name)
        tag_id = find_id(name)
        return false unless tag_id

        @clip_repository.remove_tag(clip_id, tag_id)
      end

      private

      def tags_dataset
        @database[:tags]
      end

      def clip_tags_dataset
        @database[:clip_tags]
      end

      def normalize_name(name)
        name.to_s.strip.downcase
      end

      def current_timestamp
        Time.now.utc.iso8601
      end
    end
  end
end
