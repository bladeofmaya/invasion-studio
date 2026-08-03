# frozen_string_literal: true

module InvasionStudio
  module Webui
    class GroupStatistics
      def initialize(project)
        @project = project
      end

      def call
        @project.compilation_statistics
      end
    end
  end
end
