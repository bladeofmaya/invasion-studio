# frozen_string_literal: true

Sequel.migration do
  transaction
  up do
    clips = self[:clips]
    duplicate_paths = clips.group(:storage_path)
                           .having(Sequel.function(:count, :id) > 1)
                           .select_map(:storage_path)

    duplicate_paths.each do |path|
      rows = clips.where(storage_path: path).all
      survivor = rows.max_by do |row|
        relationships = self[:compilation_clips].where(clip_id: row[:id]).count +
                        self[:clip_tags].where(clip_id: row[:id]).count +
                        self[:cuts].where(clip_id: row[:id]).count
        user_metadata = [row[:title], row[:note], row[:result]].count { |value| !value.to_s.empty? }
        [relationships, user_metadata, row[:rating].to_i, row[:source_kind] == 'uploaded' ? 1 : 0]
      end

      (rows - [survivor]).each do |duplicate|
        self[:compilation_clips].where(clip_id: duplicate[:id]).each do |membership|
          exists = self[:compilation_clips].where(
            compilation_id: membership[:compilation_id], clip_id: survivor[:id]
          ).count.positive?
          if exists
            self[:compilation_clips].where(
              compilation_id: membership[:compilation_id], clip_id: duplicate[:id]
            ).delete
          else
            self[:compilation_clips].where(
              compilation_id: membership[:compilation_id], clip_id: duplicate[:id]
            ).update(clip_id: survivor[:id])
          end
        end

        self[:clip_tags].where(clip_id: duplicate[:id]).each do |tagging|
          exists = self[:clip_tags].where(clip_id: survivor[:id], tag_id: tagging[:tag_id]).count.positive?
          if exists
            self[:clip_tags].where(clip_id: duplicate[:id], tag_id: tagging[:tag_id]).delete
          else
            self[:clip_tags].where(clip_id: duplicate[:id], tag_id: tagging[:tag_id]).update(clip_id: survivor[:id])
          end
        end

        self[:cuts].where(clip_id: duplicate[:id]).update(clip_id: survivor[:id])
        clips.where(id: duplicate[:id]).delete
      end
    end

    add_index :clips, :storage_path, unique: true, name: :clips_storage_path_unique
  end

  down do
    drop_index :clips, :storage_path, name: :clips_storage_path_unique
  end
end
