# frozen_string_literal: true

Sequel.migration do
  transaction
  up do
    create_table(:project_metadata) do
      String :key, primary_key: true
      String :value, null: true
      String :created_at, null: false
      String :updated_at, null: false
    end
  end

  down do
    drop_table(:project_metadata)
  end
end
