require 'test_helper'
require 'tmpdir'

class TestInterfaceSettings < Minitest::Test
  def test_preferences_persist_and_partial_updates_preserve_other_values
    Dir.mktmpdir do |folder|
      database = InvasionStudio::Database.migrate_to_current!(folder)
      begin
        settings = InvasionStudio::Database::ProjectSettings.new(database)
        assert_equal({ 'library_width' => 35, 'compact' => false }, settings.interface)
        assert settings.update_interface('library_width' => 42)
        assert settings.update_interface('compact' => true)
        reloaded = InvasionStudio::Database::ProjectSettings.new(database)
        assert_equal({ 'library_width' => 42, 'compact' => true }, reloaded.interface)
        [{ 'library_width' => 90 }, { 'compact' => 'true' }, { 'unknown' => 1 }, []].each do |invalid|
          refute settings.update_interface(invalid)
        end
        assert_equal({ 'library_width' => 42, 'compact' => true }, settings.interface)
      ensure
        database.disconnect
      end
    end
  end
end
