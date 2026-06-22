# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create(:test) do |t|
  t.test_globs = ["test/test_*.rb"]
end

Minitest::TestTask.create("test:system") do |t|
  t.test_globs = ["test/system/test_*.rb"]
end

Minitest::TestTask.create("test:all") do |t|
  t.test_globs = ["test/test_*.rb", "test/system/test_*.rb"]
end

task default: :test
