$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Rack's mock request mutates a request-body string's encoding, which Ruby 3.4
# reports as a future frozen-string warning. Filter only that upstream warning;
# project and dependency warnings otherwise remain visible.
original_warning = Warning.method(:warn)
Warning.define_singleton_method(:warn) do |message, **options|
  rack_frozen_string_warning = message.include?('/gems/rack-') &&
    message.include?('literal string will be frozen in the future')
  original_warning.call(message, **options) unless rack_frozen_string_warning
end

require "invasion_studio"
require "pry"

# Disable SuckerPunch background jobs during tests to avoid async SQLite conflicts
module SuckerPunch
  module Job
    module ClassMethods
      def perform_async(*)
        # no-op in test environment
      end
    end
  end
end

require "minitest/autorun"
require_relative "support/fakes"
