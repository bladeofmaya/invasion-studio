# frozen_string_literal: true

require 'monitor'

module InvasionStudio
  class Project
    module MutationLock
      MUTATIONS = %i[
        create_group rename_group delete_group add_clip_to_group remove_clip_from_group
        reorder_group update_note update_rating update_result update_title update_cuts
        finalize_cuts delete_clip restore_clip save!
      ].freeze

      MUTATIONS.each do |method_name|
        define_method(method_name) do |*args, **kwargs, &block|
          @mutation_lock.synchronize { super(*args, **kwargs, &block) }
        end
      end
    end

    prepend MutationLock

    attr_reader :folder_path, :data

    def initialize(folder_path, repository: nil, process_runner: nil, catalog: nil,
                   group_collection: nil, trash: nil, clip_finalizer: nil)
      @folder_path = File.expand_path(folder_path)
      @repository = repository || ProjectRepository.new(@folder_path)
      @mutation_lock = Monitor.new
      @data = @repository.load_or_initialize

      @catalog = catalog || ClipCatalog.new(@folder_path, @data['clips'])
      @group_collection = group_collection || GroupCollection.new(
        @data['groups'], clip_lookup: ->(id) { @catalog.find(id) }
      )
      @trash = trash || ClipTrash.new(@folder_path, @catalog)
      @clip_finalizer = clip_finalizer || ClipFinalizer.new(
        @folder_path, @catalog, process_runner: process_runner || ProcessRunner.new
      )

      sync_clips!
    end

    def clips
      @catalog.active
    end

    def all_clips
      @catalog.all
    end

    def deleted_clips
      @catalog.deleted
    end

    def groups
      @group_collection.groups
    end

    def create_group(name)
      persist_if(@group_collection.create(name))
    end

    def rename_group(old_name, new_name)
      persist_if(@group_collection.rename(old_name, new_name))
    end

    def delete_group(name)
      persist_if(@group_collection.delete(name))
    end

    def add_clip_to_group(group_name, clip_id)
      persist_if(@group_collection.add_clip(group_name, clip_id))
    end

    def remove_clip_from_group(group_name, clip_id)
      persist_if(@group_collection.remove_clip(group_name, clip_id))
    end

    def reorder_group(group_name, old_index, new_index)
      persist_if(@group_collection.reorder(group_name, old_index, new_index))
    end

    def update_note(clip_id, note)
      update_clip(clip_id) { |clip| clip['note'] = note }
    end

    def update_rating(clip_id, rating)
      update_clip(clip_id) { |clip| clip['rating'] = rating.to_i.clamp(0, 5) }
    end

    def update_result(clip_id, result)
      update_clip(clip_id) { |clip| clip['result'] = %w[win loss dc].include?(result) ? result : nil }
    end

    def update_title(clip_id, title)
      update_clip(clip_id) do |clip|
        stripped = title.to_s.strip
        clip['title'] = stripped.empty? ? nil : stripped
      end
    end

    def update_cuts(clip_id, cuts)
      plan = CutPlan.build(cuts)
      return false unless plan

      update_clip(clip_id) { |clip| clip['cuts'] = plan.cuts.map(&:dup) }
    end

    def effective_duration(clip, media_duration)
      (CutPlan.build(clip['cuts']) || CutPlan.empty).effective_duration(media_duration)
    end

    def finalize_cuts(clip_id, finalizer: nil)
      clip = find_clip(clip_id)
      return false unless clip

      success = @clip_finalizer.finalize(clip, media_operation: finalizer)
      persist_if(success)
    end

    def delete_clip(clip_id)
      clip = find_clip(clip_id)
      return false unless clip

      persist_if(@trash.delete(clip))
    end

    def restore_clip(clip_id)
      clip = find_clip(clip_id)
      return false unless clip

      persist_if(@trash.restore(clip))
    end

    def group_clips(group_name)
      @group_collection.clips(group_name)
    end

    def group_clip_paths(group_name)
      group_clips(group_name).filter_map { |clip| resolve_clip_path(clip) }
    end

    def clip_groups(clip_id)
      @group_collection.names_for_clip(clip_id)
    end

    def find_clip(clip_id)
      @catalog.find(clip_id)
    end

    def resolve_clip_path(clip)
      @catalog.path_for(clip)
    end

    def save!
      @repository.save(@data)
    end

    private

    def update_clip(clip_id)
      clip = find_clip(clip_id)
      return false unless clip

      yield clip
      save!
      true
    end

    def persist_if(success)
      return false unless success

      save!
      true
    end

    def sync_clips!
      @catalog.sync!(groups: @group_collection)
      save!
    end
  end
end
