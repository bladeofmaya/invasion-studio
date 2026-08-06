# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:cuts) do
      add_index :clip_id
    end
  end
end
