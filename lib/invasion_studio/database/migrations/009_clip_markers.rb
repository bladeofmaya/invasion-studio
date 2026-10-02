# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:clip_markers) do
      foreign_key :clip_id, :clips, type: String, null: false, on_delete: :cascade
      String :id, null: false
      Float :time, null: false
      String :event_type, null: false
      String :label, null: false, default: ''
      primary_key [:clip_id, :id]
      index [:clip_id, :time]
    end
  end
end
