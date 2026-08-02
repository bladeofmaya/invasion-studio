# frozen_string_literal: true

module InvasionStudio
  module Webui
    class GameStatistics
      def initialize(project)
        @project = project
      end

      def call
        clips = @project.clips
        results = {
          'won' => count(clips, 'win'),
          'lost' => count(clips, 'loss'),
          'dc' => count(clips, 'dc'),
          'no_result' => clips.count { |clip| clip['result'].nil? }
        }
        {
          'invasions' => clips.length,
          'duration_seconds' => clips.sum { |clip| clip['duration'].to_f },
          'results' => results,
          'win_rate' => win_rate(results)
        }
      end

      private

      def count(clips, result)
        clips.count { |clip| clip['result'] == result }
      end

      def win_rate(results)
        decided = results['won'] + results['lost']
        return nil if decided.zero?

        (results['won'].to_f / decided * 100).round(2)
      end
    end
  end
end
