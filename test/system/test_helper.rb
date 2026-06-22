require_relative '../test_helper'
require 'benchmark'

module SystemTestHelper
  def log_benchmark(label, engine, bm)
    clips = engine.clips
    puts format(
      "\n[BENCHMARK] %-30s | clips: %2d | total: %7.3fs | cpu: %7.3fs",
      label,
      clips.length,
      bm.real,
      bm.total
    )
  end
end
