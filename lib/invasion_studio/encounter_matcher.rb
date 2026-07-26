# frozen_string_literal: true

module InvasionStudio
  class EncounterMatcher
    START_REGEX = /Defeat.*Host of Fingers|Commencing combat/i
    END_REGEX = /Returning to your world|Combat ends/i

    def classify(text)
      return :start if text.match?(START_REGEX)
      return :end if text.match?(END_REGEX)

      nil
    end
  end
end
