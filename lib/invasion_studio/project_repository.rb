# frozen_string_literal: true

require 'time'

module InvasionStudio
  class ProjectRepository
    attr_reader :project_path

    def initialize(folder_path, store: nil, schema: ProjectSchema.new, clock: -> { Time.now })
      @folder_path = File.expand_path(folder_path)
      @project_path = File.join(@folder_path, 'project.json')
      @store = store || AtomicJsonStore.new(@project_path)
      @schema = schema
      @clock = clock
    end

    def load_or_initialize
      timestamp = current_timestamp
      data = @store.exist? ? @store.read : initial_data(timestamp)
      @schema.migrate(data, timestamp:)
    end

    def save(data)
      data['updated_at'] = current_timestamp
      @schema.stamp(data)
      @store.write(data)
    end

    private

    def initial_data(timestamp)
      {
        'schema_version' => ProjectSchema::CURRENT_VERSION,
        'project' => File.basename(@folder_path),
        'created_at' => timestamp,
        'updated_at' => timestamp,
        'clips' => [],
        'groups' => [{ 'name' => 'Video 1', 'clip_ids' => [] }]
      }
    end

    def current_timestamp
      @clock.call.iso8601
    end
  end
end
