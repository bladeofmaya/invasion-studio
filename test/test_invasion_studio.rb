# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "open3"
require "tmpdir"
require "invasion_studio"

class TestInvasionStudio < Minitest::Test
  def test_exposes_version_under_new_namespace
    refute_nil InvasionStudio::VERSION
  end

  def test_legacy_namespace_is_not_defined
    legacy_namespace = "Invasion" + "Extractor"

    refute Object.const_defined?(legacy_namespace)
  end

  def test_uses_xdg_cache_home
    Dir.mktmpdir do |directory|
      previous = ENV["XDG_CACHE_HOME"]
      ENV["XDG_CACHE_HOME"] = directory

      assert_equal File.join(directory, "invasion-studio"), InvasionStudio::Paths.cache_dir
    ensure
      ENV["XDG_CACHE_HOME"] = previous
    end
  end

  def test_exposes_xdg_application_directories
    Dir.mktmpdir do |directory|
      environment = {
        "XDG_CONFIG_HOME" => File.join(directory, "config"),
        "XDG_CACHE_HOME" => File.join(directory, "cache"),
        "XDG_DATA_HOME" => File.join(directory, "data"),
        "XDG_STATE_HOME" => File.join(directory, "state")
      }

      with_environment(environment) do
        assert_equal File.join(directory, "config", "invasion-studio"), InvasionStudio::Paths.config_dir
        assert_equal File.join(directory, "cache", "invasion-studio"), InvasionStudio::Paths.cache_dir
        assert_equal File.join(directory, "data", "invasion-studio"), InvasionStudio::Paths.data_dir
        assert_equal File.join(directory, "state", "invasion-studio"), InvasionStudio::Paths.state_dir
      end
    end
  end

  def test_ignores_relative_xdg_paths
    with_environment("XDG_CACHE_HOME" => "relative/cache") do
      assert_equal File.join(Dir.home, ".cache", "invasion-studio"), InvasionStudio::Paths.cache_dir
    end
  end

  def test_gem_uses_new_public_name_and_executable
    gemspec = Gem::Specification.load(File.expand_path("../invasion-studio.gemspec", __dir__))

    assert_equal "invasion-studio", gemspec.name
    assert_equal ["invasion-studio"], gemspec.executables
  end

  def test_gem_packages_offline_webui_assets_and_licenses
    gemspec = Gem::Specification.load(File.expand_path("../invasion-studio.gemspec", __dir__))

    expected_files = %w[
      lib/invasion_studio/webui/views/index.erb
      lib/invasion_studio/webui/public/assets/app.css
      lib/invasion_studio/webui/public/assets/app.js
      MIT-LICENSE
      THIRD_PARTY_LICENSES.md
    ]

    assert_empty expected_files - gemspec.files
  end

  def test_executable_loads_the_gem_from_the_checkout
    executable = File.expand_path("../bin/invasion-studio", __dir__)
    stdout, stderr, status = Open3.capture3(
      { "RUBYLIB" => nil },
      Gem.ruby,
      executable,
      "--version",
      chdir: Dir.tmpdir
    )

    assert status.success?, stderr
    assert_equal "Invasion Studio v#{InvasionStudio::VERSION}\n", stdout
  end

  private

  def with_environment(values)
    previous_values = values.to_h { |key, _value| [key, ENV[key]] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous_values.each { |key, value| ENV[key] = value }
  end
end
