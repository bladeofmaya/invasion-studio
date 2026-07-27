# frozen_string_literal: true

require 'monitor'

module InvasionStudio
  class Project
    DB_SCHEMA_VERSION = 1

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

    attr_reader :folder_path

    def initialize(folder_path, database: nil, storage: nil, process_runner: nil,
                   clip_repository: nil, group_repository: nil, tag_repository: nil,
                   clip_trash: nil, clip_finalizer: nil)
      @folder_path = File.expand_path(folder_path)
      @mutation_lock = Monitor.new
      @database = database || InvasionStudio::Database.migrate_to_current!(@folder_path)
      @storage = storage || InvasionStudio::Storage::LocalDiskStorage.new(@folder_path)
      @clip_repository = clip_repository || InvasionStudio::Database::ClipRepository.new(@database, @storage)
      @group_repository = group_repository || InvasionStudio::Database::GroupRepository.new(
        @database, clip_repository: @clip_repository
      )
      @tag_repository = tag_repository || InvasionStudio::Database::TagRepository.new(
        @database, clip_repository: @clip_repository
      )
      @clip_trash = clip_trash || ClipTrash.new(@folder_path, @storage)
      @clip_finalizer = clip_finalizer || ClipFinalizer.new(
        @folder_path, @storage, process_runner: process_runner || ProcessRunner.new
      )

      InvasionStudio::Database::LegacyProjectImporter.new(
        @database, @folder_path
      ).run_if_needed

      sync_clips!
      ensure_default_group!
    end

    def data
      {
        'schema_version' => DB_SCHEMA_VERSION,
        'project' => File.basename(@folder_path),
        'created_at' => created_at,
        'updated_at' => Time.now.utc.iso8601,
        'clips' => clips,
        'groups' => groups
      }
    end

    def clips
      @clip_repository.active
    end

    def all_clips
      @clip_repository.all
    end

    def deleted_clips
      @clip_repository.deleted
    end

    def groups
      @group_repository.all
    end

    def create_group(name)
      @group_repository.create(name.to_s.strip)
    end

    def rename_group(old_name, new_name)
      @group_repository.rename(old_name, new_name)
    end

    def delete_group(name)
      @group_repository.delete(name)
    end

    def add_clip_to_group(group_name, clip_id)
      @group_repository.add_clip(group_name, clip_id)
    end

    def remove_clip_from_group(group_name, clip_id)
      @group_repository.remove_clip(group_name, clip_id)
    end

    def reorder_group(group_name, old_index, new_index)
      @group_repository.reorder(group_name, old_index.to_i, new_index.to_i)
    end

    def update_note(clip_id, note)
      return false unless find_clip(clip_id)

      @clip_repository.update(clip_id, 'note' => note)
    end

    def update_rating(clip_id, rating)
      return false unless find_clip(clip_id)

      @clip_repository.update(clip_id, 'rating' => rating.to_i)
    end

    def update_result(clip_id, result)
      return false unless find_clip(clip_id)

      @clip_repository.update(clip_id, 'result' => result)
    end

    def update_title(clip_id, title)
      return false unless find_clip(clip_id)

      @clip_repository.update(clip_id, 'title' => title)
    end

    def update_cuts(clip_id, cuts)
      return false unless find_clip(clip_id)

      @clip_repository.update_cuts(clip_id, cuts)
    end

    def effective_duration(clip, media_duration)
      (CutPlan.build(clip['cuts']) || CutPlan.empty).effective_duration(media_duration)
    end

    def finalize_cuts(clip_id, finalizer: nil)
      clip = find_clip(clip_id)
      return false unless clip

      success = @clip_finalizer.finalize(clip, media_operation: finalizer)
      update_cuts(clip_id, []) if success
      success
    end

    def delete_clip(clip_id)
      clip = find_clip(clip_id)
      return false unless clip

      success = @clip_trash.delete(clip)
      return false unless success

      @clip_repository.mark_deleted(clip_id, deleted_path: clip['trash_path'])
    end

    def restore_clip(clip_id)
      clip = find_clip(clip_id)
      return false unless clip

      success = @clip_trash.restore(clip)
      return false unless success

      @clip_repository.mark_restored(clip_id)
    end

    def group_clips(group_name)
      @group_repository.clips(group_name)
    end

    def group_clip_paths(group_name)
      @group_repository.clip_paths(group_name)
    end

    def clip_groups(clip_id)
      @group_repository.names_for_clip(clip_id)
    end

    def find_clip(clip_id)
      @clip_repository.find(clip_id)
    end

    def resolve_clip_path(clip)
      @clip_repository.path_for(clip)
    end

    def save!
      true
    end

    def add_tag(clip_id, name)
      @tag_repository.add_to_clip(clip_id, name)
    end

    def remove_tag(clip_id, name)
      @tag_repository.remove_from_clip(clip_id, name)
    end

    def clip_tags(clip_id)
      @clip_repository.tags_for(clip_id)
    end

    private

    def created_at
      stat = File.stat(@folder_path)
      stat.ctime.utc.iso8601
    rescue StandardError
      Time.now.utc.iso8601
    end

    def sync_clips!
      discover_new_clips
      @clip_repository.remove_missing
      @group_repository.prune(@clip_repository.all.map { |clip| clip['id'] })
      @tag_repository.delete_unused
    end

    def ensure_default_group!
      return if @group_repository.all.any?

      @group_repository.create('Video 1')
    end

    def discover_new_clips
      known_ids = @clip_repository.all.map { |clip| clip['id'] }
      known_filenames = @clip_repository.all.map { |clip| clip['filename'] }

      MediaFiles.discover(@folder_path).each do |path|
        filename = File.basename(path)
        next if known_filenames.include?(filename)

        base_id = File.basename(filename, '.*')
        clip_id = known_ids.include?(base_id) ? "#{base_id}-#{SecureRandom.uuid}" : base_id
        known_ids << clip_id

        @clip_repository.create(
          'id' => clip_id,
          'filename' => filename,
          'path' => @clip_repository.relative_path(path),
          'title' => nil,
          'note' => '',
          'rating' => 0,
          'result' => nil,
          'source_kind' => 'external',
          'duration' => nil,
          'filesize' => nil,
          'width' => nil,
          'height' => nil,
          'fps' => nil,
          'video_codec' => nil,
          'audio_codec' => nil,
          'thumbnail_path' => nil
        )
      end
    end
  end
end
