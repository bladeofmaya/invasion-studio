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

      # All tags with the number of non-trashed clips carrying each.
      def details
        counts = clip_tags_dataset
                 .join(:clips, id: :clip_id)
                 .where(Sequel[:clips][:deleted_at] => nil)
                 .group_and_count(:tag_id)
                 .to_hash(:tag_id, :count)
        tags_dataset.order(:name).all.map do |tag|
          { 'name' => tag[:name], 'clip_count' => counts[tag[:id]] || 0 }
        end
      end

      def rename(old_name, new_name)
        old_name = normalize_name(old_name)
        new_name = normalize_name(new_name)
        return false if new_name.empty?

        tag = tags_dataset.where(name: old_name).first
        return false unless tag
        return true if new_name == old_name
        return false if tags_dataset.where(name: new_name).count.positive?

        tags_dataset.where(id: tag[:id]).update(name: new_name)
        true
      end

      def delete(name)
        tag_id = find_id(name)
        return false unless tag_id

        @database.transaction do
          clip_tags_dataset.where(tag_id: tag_id).delete
          tags_dataset.where(id: tag_id).delete
        end
        true
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
