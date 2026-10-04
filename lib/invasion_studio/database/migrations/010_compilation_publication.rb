# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:compilations) do
      add_column :youtube_url, String, null: false, default: ''
      add_column :cover_path, String
      add_column :archived_at, String
    end
    from(:compilations).where(archived: true).update(archived_at: Sequel[:updated_at])
  end

  down do
    alter_table(:compilations) do
      drop_column :youtube_url
      drop_column :cover_path
      drop_column :archived_at
    end
  end
end
