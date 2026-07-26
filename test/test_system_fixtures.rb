require 'test_helper'
require_relative 'support/system_fixtures'

class TestSystemFixtures < Minitest::Test
  def test_invasion_fixture_contract
    fixture = TestSupport::SystemFixtures::INVASION

    assert_equal 'invasion-sample-720p', fixture.label
    assert_equal 2, fixture.expected_segments
    assert_equal :extract, fixture.mode
    assert_equal :invasion, fixture.marker_family
    assert File.file?(fixture.path)
  end

  def test_arena_fixture_contract
    fixture = TestSupport::SystemFixtures::ARENA

    assert_equal 'arena-sample-720p', fixture.label
    assert_equal 4, fixture.expected_segments
    assert_equal :scan, fixture.mode
    assert_equal :arena, fixture.marker_family
    assert File.file?(fixture.path)
  end

  def test_fixture_paths_are_absolute_and_unique
    fixtures = TestSupport::SystemFixtures.all

    assert fixtures.all? { |fixture| fixture.path.start_with?('/') }
    assert_equal fixtures.length, fixtures.map(&:path).uniq.length
  end
end
