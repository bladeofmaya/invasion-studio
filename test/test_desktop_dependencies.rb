require 'test_helper'
require_relative '../desktop/runtime_dependencies'
require 'open3'

class TestDesktopDependencies < Minitest::Test
  def test_writes_a_gemfile_with_exact_runtime_versions
    assert_equal "source \"https://rubygems.org\"\n\ngem \"rack\", \"= 3.2.7\"\ngem \"sinatra\", \"= 4.2.1\"\n",
                 DesktopPackaging.gemfile({ 'rack' => '3.2.7', 'sinatra' => '4.2.1' })
  end

  def test_stages_a_runtime_only_application_with_bundler_activation
    Dir.mktmpdir('studio-desktop-stage-') do |stage|
      script = File.expand_path('../desktop/prepare-sidecar.rb', __dir__)
      output, status = Open3.capture2e(RbConfig.ruby, script, stage)
      assert status.success?, output
      gemfile = File.read(File.join(stage, 'Gemfile'))
      assert_includes gemfile, 'gem "sinatra", "= '
      assert_includes gemfile, 'gem "sqlite3", "= '
      refute_includes gemfile, 'gemspec'
      refute_includes gemfile, 'gem "pry"'
      refute_includes gemfile, 'gem "minitest"'
      entry = File.read(File.join(stage, 'desktop-entry.rb'))
      assert_includes entry, "require 'bundler/setup'"
      assert_includes entry, "File.expand_path('bin/invasion-studio', __dir__)"
      assert JSON.parse(File.read(File.join(stage, 'desktop-dependencies.json'))).key?('puma')
    end
  end

  def test_pins_runtime_dependency_closure_without_development_gems
    dependency = ->(name, type = :runtime) { Gem::Dependency.new(name, '>= 0', type) }
    spec = ->(name, version, dependencies) { Struct.new(:name, :version, :dependencies).new(name, version, dependencies) }
    specs = [spec.call('app', '1.0', [dependency.call('web'), dependency.call('tests', :development)]),
             spec.call('web', '2.0', [dependency.call('http')]),
             spec.call('http', '3.0', []), spec.call('tests', '4.0', [])]
    assert_equal({ 'http' => '3.0', 'web' => '2.0' },
                 DesktopPackaging.runtime_dependencies(specs, 'app'))
  end
end
