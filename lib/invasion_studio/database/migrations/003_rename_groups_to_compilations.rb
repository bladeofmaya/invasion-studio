# frozen_string_literal: true

Sequel.migration do
  transaction
  up do
    rename_table :groups, :compilations
    rename_table :group_clips, :compilation_clips
    alter_table(:compilation_clips) do
      rename_column :group_id, :compilation_id
    end
  end

  down do
    alter_table(:compilation_clips) do
      rename_column :compilation_id, :group_id
    end
    rename_table :compilation_clips, :group_clips
    rename_table :compilations, :groups
  end
end
