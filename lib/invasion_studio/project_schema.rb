# frozen_string_literal: true

module InvasionStudio
  class UnsupportedProjectVersion < Error; end
  class InvalidProjectData < Error; end

  class ProjectSchema
    CURRENT_VERSION = 1

    def migrate(data, timestamp:)
      raise InvalidProjectData, 'Project data must be a JSON object' unless data.is_a?(Hash)

      version = Integer(data.fetch('schema_version', 0), exception: false)
      raise InvalidProjectData, 'Project schema version must be an integer' unless version
      if version > CURRENT_VERSION
        raise UnsupportedProjectVersion,
              "Project schema version #{version} is newer than supported version #{CURRENT_VERSION}"
      end

      migrated = data
      migrate_version_zero(migrated, timestamp:) if version.zero?
      validate_collections!(migrated)
      migrated['schema_version'] = CURRENT_VERSION
      migrated
    end

    def stamp(data)
      data['schema_version'] = CURRENT_VERSION
      data
    end

    private

    def migrate_version_zero(data, timestamp:)
      data['created_at'] ||= timestamp
      data['updated_at'] ||= timestamp
      data['clips'] ||= []
      data['groups'] ||= []
    end

    def validate_collections!(data)
      raise InvalidProjectData, 'Project clips must be an array' unless data['clips'].is_a?(Array)
      raise InvalidProjectData, 'Project groups must be an array' unless data['groups'].is_a?(Array)
    end
  end
end
