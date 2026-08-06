# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'open3'

class TestBumpVersion < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@root, 'bin'))
    FileUtils.mkdir_p(File.join(@root, 'lib/invasion_studio'))
    FileUtils.mkdir_p(File.join(@root, 'desktop/electron'))
    FileUtils.cp(File.expand_path('../bin/bump-version', __dir__), File.join(@root, 'bin/bump-version'))
    File.write(File.join(@root, 'lib/invasion_studio/version.rb'), <<~RUBY)
      module InvasionStudio
        VERSION = "0.7.1"
      end
    RUBY
    write_json('desktop/electron/package.json', 'version' => '0.7.1')
    write_json('desktop/electron/package-lock.json',
               'version' => '0.7.1', 'packages' => { '' => { 'version' => '0.7.1' } })
    File.write(File.join(@root, 'Gemfile.lock'), "BUNDLED WITH\n   2.4.22\n")

    @fake_bin = File.join(@root, 'fake-bin')
    FileUtils.mkdir_p(@fake_bin)
    File.write(File.join(@fake_bin, 'bundle'), "#!/bin/sh\nexit 0\n")
    FileUtils.chmod(0o755, File.join(@fake_bin, 'bundle'))
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def test_accepts_a_v_prefixed_prerelease_label
    stdout, stderr, status = run_bump('v0.8.0-dev')

    assert status.success?, stderr
    assert_includes stdout, 'Version: 0.7.1 -> 0.8.0-dev'
    assert_includes File.read(File.join(@root, 'lib/invasion_studio/version.rb')), 'VERSION = "0.8.0-dev"'
    assert_equal '0.8.0-dev', read_json('desktop/electron/package.json').fetch('version')
    lock = read_json('desktop/electron/package-lock.json')
    assert_equal '0.8.0-dev', lock.fetch('version')
    assert_equal '0.8.0-dev', lock.dig('packages', '', 'version')
  end

  def test_can_bump_from_a_prerelease_version
    run_bump('0.8.0-dev')

    _stdout, stderr, status = run_bump('patch')

    assert status.success?, stderr
    assert_includes File.read(File.join(@root, 'lib/invasion_studio/version.rb')), 'VERSION = "0.8.1"'
  end

  private

  def run_bump(version)
    Open3.capture3({ 'PATH' => "#{@fake_bin}:#{ENV.fetch('PATH')}" },
                   RbConfig.ruby, File.join(@root, 'bin/bump-version'), version)
  end

  def write_json(path, value)
    File.write(File.join(@root, path), "#{JSON.pretty_generate(value)}\n")
  end

  def read_json(path)
    JSON.parse(File.read(File.join(@root, path)))
  end
end
