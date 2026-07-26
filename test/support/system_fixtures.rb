# frozen_string_literal: true

module TestSupport
  module SystemFixtures
    Fixture = Data.define(:label, :path, :expected_segments, :mode, :marker_family)
    SAMPLES_DIR = File.expand_path('../samples', __dir__)

    INVASION = Fixture.new(
      'invasion-sample-720p',
      File.join(SAMPLES_DIR, 'invasion-sample-720p.mp4'),
      2,
      :extract,
      :invasion
    )
    ARENA = Fixture.new(
      'arena-sample-720p',
      File.join(SAMPLES_DIR, 'arena-sample-720p.mp4'),
      4,
      :scan,
      :arena
    )

    def self.all
      [INVASION, ARENA].freeze
    end
  end
end
