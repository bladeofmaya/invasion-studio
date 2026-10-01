# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:recording_imports) do
      String :digest, primary_key: true
      String :source_path, null: false
      String :created_at, null: false
    end
  end
end
