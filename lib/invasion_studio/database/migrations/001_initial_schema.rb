# frozen_string_literal: true

Sequel.migration do
  transaction
  up do
    create_table(:clips) do
      String :id, primary_key: true
      String :title, null: true
      String :note, null: false, default: ''
      Integer :rating, null: false, default: 0
      String :result, null: true
      String :source_kind, null: false, default: 'uploaded'
      String :original_filename, null: false
      String :storage_path, null: false
      Float :duration, null: true
      Integer :filesize, null: true
      Integer :width, null: true
      Integer :height, null: true
      Float :fps, null: true
      String :video_codec, null: true
      String :audio_codec, null: true
      String :thumbnail_path, null: true
      String :deleted_at, null: true
      String :deleted_path, null: true
      String :created_at, null: false
      String :updated_at, null: false
    end

    create_table(:tags) do
      primary_key :id
      String :name, null: false, unique: true
      String :created_at, null: false
    end

    create_table(:clip_tags) do
      foreign_key :clip_id, :clips, type: String, null: false, on_delete: :cascade
      foreign_key :tag_id, :tags, null: false, on_delete: :cascade
      String :created_at, null: false
      primary_key [:clip_id, :tag_id]
    end

    create_table(:groups) do
      primary_key :id
      String :name, null: false, unique: true
      Integer :position, null: false, default: 0
      String :created_at, null: false
      String :updated_at, null: false
    end

    create_table(:group_clips) do
      foreign_key :group_id, :groups, null: false, on_delete: :cascade
      foreign_key :clip_id, :clips, type: String, null: false, on_delete: :cascade
      Integer :position, null: false, default: 0
      String :created_at, null: false
      primary_key [:group_id, :clip_id]
    end

    create_table(:cuts) do
      primary_key :id
      foreign_key :clip_id, :clips, type: String, null: false, on_delete: :cascade
      Integer :position, null: false, default: 0
      Float :start, null: false
      Float :end, null: false
      String :created_at, null: false
      String :updated_at, null: false
    end

  end

  down do
    drop_table(:cuts)
    drop_table(:group_clips)
    drop_table(:groups)
    drop_table(:clip_tags)
    drop_table(:tags)
    drop_table(:clips)
  end
end
