# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:compilations) do
      add_column :description, String, text: true, null: false, default: ''
      add_column :archived, TrueClass, null: false, default: false
    end
  end
end
