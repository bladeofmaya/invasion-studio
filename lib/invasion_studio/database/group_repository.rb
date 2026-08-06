# frozen_string_literal: true

module InvasionStudio
  module Database
    class GroupRepository
      def initialize(database, clip_repository:)
        @database = database
        @clip_repository = clip_repository
      end

      def all
        groups_dataset.order(:position, :id).map { |group| group_attributes(group) }
      end

      def names
        groups_dataset.select_map(:name)
      end

      def find(name)
        group = groups_dataset.where(name: name).first
        return nil unless group

        group_attributes(group)
      end

      def create(name)
        return false unless CompilationName.valid?(name)
        return false if name_taken?(name)

        timestamp = current_timestamp
        max_position = groups_dataset.max(:position) || 0
        groups_dataset.insert(
          name: name,
          position: max_position + 1,
          created_at: timestamp,
          updated_at: timestamp
        )
        true
      end

      def rename(old_name, new_name)
        old_name = old_name.to_s
        new_name = new_name.to_s
        return false if old_name == new_name
        return false unless CompilationName.valid?(new_name)
        return false if name_taken?(new_name, except: old_name)

        groups_dataset.where(name: old_name).update(
          name: new_name,
          updated_at: current_timestamp
        )
        true
      end

      def delete(name)
        group = find(name)
        return false unless group

        @database.transaction do
          group_clips_dataset.where(compilation_id: group['id']).delete
          groups_dataset.where(id: group['id']).delete
          compact_positions
        end
        true
      end

      def add_clip(group_name, clip_id)
        group = find(group_name)
        return false unless group
        return false unless @clip_repository.exist?(clip_id)
        return false if group_clips_dataset.where(compilation_id: group['id'], clip_id: clip_id).count.positive?

        max_position = group_clips_dataset.where(compilation_id: group['id']).max(:position) || 0
        group_clips_dataset.insert(
          compilation_id: group['id'],
          clip_id: clip_id,
          position: max_position + 1,
          created_at: current_timestamp
        )
        true
      end

      def remove_clip(group_name, clip_id)
        group = find(group_name)
        return false unless group

        deleted = group_clips_dataset.where(compilation_id: group['id'], clip_id: clip_id).delete
        return false if deleted.zero?

        compact_group_positions(group['id'])
        true
      end

      def move_clip(source_name, destination_name, clip_id)
        source = find(source_name)
        destination = find(destination_name)
        return false unless source && destination
        return false if source['id'] == destination['id']

        source_membership = group_clips_dataset.where(
          compilation_id: source['id'], clip_id: clip_id
        )
        return false if source_membership.count.zero?

        @database.transaction do
          destination_membership = group_clips_dataset.where(
            compilation_id: destination['id'], clip_id: clip_id
          )
          if destination_membership.count.zero?
            max_position = group_clips_dataset.where(compilation_id: destination['id']).max(:position) || 0
            group_clips_dataset.insert(
              compilation_id: destination['id'], clip_id: clip_id,
              position: max_position + 1, created_at: current_timestamp
            )
          end
          source_membership.delete
          compact_group_positions(source['id'])
          groups_dataset.where(id: [source['id'], destination['id']]).update(updated_at: current_timestamp)
        end
        true
      end

      def reorder(group_name, old_index, new_index)
        group = find(group_name)
        return false unless group

        clip_ids = group_clips_dataset.where(compilation_id: group['id'])
                                    .order(:position, :created_at)
                                    .select_map(:clip_id)
        return false unless valid_index?(old_index, clip_ids) && valid_index?(new_index, clip_ids)

        clip_ids.insert(new_index, clip_ids.delete_at(old_index))
        @database.transaction do
          clip_ids.each_with_index do |clip_id, position|
            group_clips_dataset.where(compilation_id: group['id'], clip_id: clip_id)
                              .update(position: position)
          end
          groups_dataset.where(id: group['id']).update(updated_at: current_timestamp)
        end
        true
      end

      def clips(group_name)
        group = find(group_name)
        return [] unless group

        clip_ids = group_clips_dataset.where(compilation_id: group['id'])
                                    .order(:position, :created_at)
                                    .select_map(:clip_id)
        clip_ids.filter_map { |id| @clip_repository.find(id) }
                .reject { |clip| clip['deleted'] }
      end

      def statistics
        compilations = groups_dataset.order(:position, :id).select(:id, :name).all
        memberships = active_memberships
        cuts_by_clip = cuts_for(memberships.map { |row| row[:clip_id] }.uniq)
        durations = effective_durations(memberships, cuts_by_clip)
        memberships_by_compilation = memberships.group_by { |row| row[:compilation_id] }

        compilations.map do |compilation|
          clips = memberships_by_compilation.fetch(compilation[:id], [])
          {
            'name' => compilation[:name],
            'clip_count' => clips.length,
            'total_duration' => clips.sum { |clip| durations.fetch(clip[:clip_id], 0.0) }.round(2)
          }
        end
      end

      def clip_paths(group_name)
        clips(group_name).filter_map { |clip| @clip_repository.resolve(clip['path']) }
      end

      def names_for_clip(clip_id)
        groups_dataset.join(:compilation_clips, compilation_id: :id)
                      .where(Sequel[:compilation_clips][:clip_id] => clip_id)
                      .select_map(Sequel[:compilations][:name])
      end

      def prune(valid_ids)
        group_clips_dataset.exclude(clip_id: valid_ids).delete
      end

      def ids_for_all
        groups_dataset.select_map(:id)
      end

      private

      def name_taken?(name, except: nil)
        identity = CompilationName.identity(name)
        names.any? do |existing_name|
          existing_name != except && CompilationName.identity(existing_name) == identity
        end
      end

      def groups_dataset
        @database[:compilations]
      end

      def group_clips_dataset
        @database[:compilation_clips]
      end

      def cuts_dataset
        @database[:cuts]
      end

      def active_memberships
        group_clips_dataset
          .join(:clips, id: :clip_id)
          .where(Sequel[:clips][:deleted_at] => nil)
          .select(
            Sequel[:compilation_clips][:compilation_id].as(:compilation_id),
            Sequel[:clips][:id].as(:clip_id),
            Sequel[:clips][:duration].as(:duration)
          )
          .all
      end

      def cuts_for(clip_ids)
        return {} if clip_ids.empty?

        cuts_dataset.where(clip_id: clip_ids).order(:clip_id, :position, :start).all
                    .group_by { |cut| cut[:clip_id] }
      end

      def effective_durations(memberships, cuts_by_clip)
        memberships.each_with_object({}) do |membership, durations|
          clip_id = membership[:clip_id]
          next if durations.key?(clip_id)

          cuts = cuts_by_clip.fetch(clip_id, []).map do |cut|
            { 'start' => cut[:start], 'end' => cut[:end] }
          end
          durations[clip_id] = (CutPlan.build(cuts) || CutPlan.empty)
                               .effective_duration(membership[:duration])
        end
      end

      def group_attributes(group)
        {
          'id' => group[:id],
          'name' => group[:name],
          'position' => group[:position],
          'clip_ids' => group_clips_dataset.where(compilation_id: group[:id])
                                          .order(:position, :created_at)
                                          .select_map(:clip_id),
          'created_at' => group[:created_at],
          'updated_at' => group[:updated_at]
        }
      end

      def compact_positions
        groups_dataset.order(:position, :id).all.each_with_index do |group, index|
          groups_dataset.where(id: group[:id]).update(position: index)
        end
      end

      def compact_group_positions(group_id)
        group_clips_dataset.where(compilation_id: group_id)
                          .order(:position, :created_at)
                          .all.each_with_index do |row, index|
          group_clips_dataset.where(compilation_id: group_id, clip_id: row[:clip_id])
                            .update(position: index)
        end
      end

      def valid_index?(index, items)
        index.is_a?(Integer) && index >= 0 && index < items.length
      end

      def current_timestamp
        Time.now.utc.iso8601
      end
    end
  end
end
