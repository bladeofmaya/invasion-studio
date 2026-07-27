# frozen_string_literal: true

Sequel.migration do
  transaction
  up do
    alter_table(:clips) do
      add_column :source_video, String, null: true
    end
  end

  down do
    alter_table(:clips) do
      drop_column :source_video
    end
  end
end
