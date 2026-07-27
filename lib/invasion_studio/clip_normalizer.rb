# frozen_string_literal: true

module InvasionStudio
  # Renames a project's clips to the generic sequential naming convention
  # (clip_00001.mp4, clip_00002.mp4, ...) in their current library order,
  # compacting numbering gaps. Renames the video file and its thumbnail and
  # rewrites the clip id everywhere it is referenced (compilations, tags,
  # cuts). Trashed clips are skipped so restoring them keeps working.
  class ClipNormalizer
    NAME_FORMAT = 'clip_%05d'

    def initialize(database:, storage:, repository:)
      @database = database
      @storage = storage
      @repository = repository
    end

    # Returns the rename plan as [{ id:, new_id:, filename:, new_filename: }]
    # without touching anything. Clips already conforming are not included.
    def plan
      clips = @repository.active
      reserved = @repository.deleted.map { |clip| clip['id'] }

      number = 0
      clips.filter_map do |clip|
        number += 1
        number += 1 while reserved.include?(format(NAME_FORMAT, number))

        new_id = format(NAME_FORMAT, number)
        new_filename = new_id + File.extname(clip['filename'])
        next if clip['id'] == new_id && clip['filename'] == new_filename

        thumbnail_path = thumbnail_key(clip)
        {
          id: clip['id'],
          new_id: new_id,
          filename: clip['filename'],
          new_filename: new_filename,
          path: clip['path'],
          new_path: replace_basename(clip['path'], new_filename),
          thumbnail_path: thumbnail_path,
          new_thumbnail_path: thumbnail_path ? "thumbnails/#{new_id}.jpg" : nil
        }
      end
    end

    # Executes the plan and returns it. Files are renamed in two phases via
    # temporary names so shifting numbers down can never collide with a file
    # that has not moved yet.
    def run
      changes = plan
      return changes if changes.empty?

      missing = changes.reject { |change| @storage.exist?(change[:path]) }
      unless missing.empty?
        names = missing.map { |change| change[:filename] }.join(', ')
        raise InvasionStudio::Error, "Cannot normalize, files are missing: #{names}"
      end

      performed = []
      begin
        rename_files(changes, performed)
        update_database(changes)
      rescue StandardError
        performed.reverse_each { |from, to| @storage.move(to, from) }
        raise
      end
      changes
    end

    private

    def rename_files(changes, performed)
      changes.each do |change|
        move!(change[:path], temp_key(change[:new_path]), performed)
        if change[:thumbnail_path] && @storage.exist?(change[:thumbnail_path])
          move!(change[:thumbnail_path], temp_key(change[:new_thumbnail_path]), performed)
        end
      end
      changes.each do |change|
        move!(temp_key(change[:new_path]), change[:new_path], performed)
        if change[:thumbnail_path] && @storage.exist?(temp_key(change[:new_thumbnail_path]))
          move!(temp_key(change[:new_thumbnail_path]), change[:new_thumbnail_path], performed)
        end
      end
    end

    def move!(from, to, performed)
      moved = @storage.move(from, to)
      raise InvasionStudio::Error, "Failed to rename #{from} to #{to}" unless moved

      performed << [from, to]
    end

    CHILD_TABLES = %i[compilation_clips clip_tags cuts].freeze

    # The clip id is the primary key referenced by compilation_clips,
    # clip_tags, and cuts (no ON UPDATE CASCADE). New ids can equal other
    # clips' old ids (numbers shifting down, swaps), so renaming row by row
    # would hit primary-key collisions. Instead: capture the child rows,
    # delete all changed clips (cascading the children away), reinsert them
    # under their new ids, then reinsert the children re-pointed.
    def update_database(changes)
      timestamp = Time.now.utc.iso8601
      ids = changes.map { |change| change[:id] }
      mapping = changes.to_h { |change| [change[:id], change[:new_id]] }

      @database.transaction do
        children = CHILD_TABLES.to_h { |table| [table, @database[table].where(clip_id: ids).all] }
        rows = @database[:clips].where(id: ids).all.to_h { |row| [row[:id], row] }
        @database[:clips].where(id: ids).delete

        changes.each do |change|
          row = rows.fetch(change[:id])
          row[:id] = change[:new_id]
          row[:original_filename] = change[:new_filename]
          row[:storage_path] = change[:new_path]
          row[:thumbnail_path] = change[:new_thumbnail_path] if change[:new_thumbnail_path]
          row[:updated_at] = timestamp
          @database[:clips].insert(row)
        end

        children.each do |table, child_rows|
          child_rows.each do |row|
            @database[table].insert(row.merge(clip_id: mapping.fetch(row[:clip_id])))
          end
        end
      end
    end

    # Discovery registers clips with a NULL thumbnail_path even when a
    # thumbnail already exists on disk (the job links it later) — fall back
    # to the conventional key so the file is renamed and linked, not orphaned.
    def thumbnail_key(clip)
      return clip['thumbnail_path'] if clip['thumbnail_path']

      safe_id = clip['id'].to_s.gsub(/[^a-zA-Z0-9_-]/, '_')
      key = "thumbnails/#{safe_id}.jpg"
      @storage.exist?(key) ? key : nil
    end

    def temp_key(key)
      "#{key}.norm-tmp"
    end

    def replace_basename(path, new_filename)
      dir = File.dirname(path)
      dir == '.' ? new_filename : File.join(dir, new_filename)
    end
  end
end
