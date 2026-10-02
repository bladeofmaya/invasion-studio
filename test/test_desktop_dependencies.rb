require 'test_helper'
require_relative '../desktop/runtime_dependencies'

class TestDesktopDependencies < Minitest::Test
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
