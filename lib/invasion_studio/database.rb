# frozen_string_literal: true

require 'sequel'
require 'sequel/extensions/migration'

module InvasionStudio
  module Database
    class Error < InvasionStudio::Error; end

    MIGRATIONS_PATH = File.expand_path('database/migrations', __dir__)

    def self.connect(path)
      Sequel.connect("sqlite://#{path}",
                     timeout: 5000,
                     connection_validation_timeout: 30)
    end

    def self.migrate(database)
      Sequel::IntegerMigrator.run(database, MIGRATIONS_PATH)
    end

    def self.migrate_to_current!(folder_path)
      FileUtils.mkdir_p(folder_path)
      db_path = File.join(folder_path, 'project.db')
      database = connect(db_path)
      migrate(database)
      database
    end
  end
end
