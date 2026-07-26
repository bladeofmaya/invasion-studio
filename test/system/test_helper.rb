require_relative '../test_helper'
require_relative '../support/system_fixtures'
require 'benchmark'

module SystemTestHelper
  def log_benchmark(fixture, engine, bm)
    clips = engine.clips
    puts format(
      "\n[BENCHMARK] %-30s | clips: %2d | total: %7.3fs | cpu: %7.3fs",
      fixture.label,
      clips.length,
      bm.real,
      bm.total
    )
  end
end
