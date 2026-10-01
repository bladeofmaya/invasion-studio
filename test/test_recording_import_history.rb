require 'test_helper'

class TestRecordingImportHistory < Minitest::Test
  def setup
    @folder = Dir.mktmpdir
    @db = InvasionStudio::Database.migrate_to_current!(@folder)
    @history = InvasionStudio::RecordingImportHistory.new(@db)
    @source = File.join(@folder, 'recording.mp4')
    File.write(@source, 'dummy recording contents')
  end

  def teardown
    @db.disconnect
    FileUtils.rm_rf(@folder)
  end

  def test_identifies_copies_and_persists_history
    fingerprints = @history.fingerprints([@source])
    @history.reserve(fingerprints)
    copy = File.join(@folder, 'renamed.mp4')
    FileUtils.cp(@source, copy)
    reopened = InvasionStudio::RecordingImportHistory.new(@db)
    assert_raises(InvasionStudio::Error) { reopened.reserve(reopened.fingerprints([copy])) }
    reopened.reserve(reopened.fingerprints([copy]), allow_reimport: true)
    File.write(copy, 'different recording')
    reopened.reserve(reopened.fingerprints([copy]))
  end

  def test_rejects_duplicates_in_one_batch_and_leaves_new_files_unreserved
    copy = File.join(@folder, 'copy.mp4')
    FileUtils.cp(@source, copy)
    assert_raises(InvasionStudio::Error) { @history.fingerprints([@source, copy]) }
    first = @history.fingerprints([@source])
    @history.reserve(first)
    File.write(copy, 'new contents')
    both = @history.fingerprints([copy, @source])
    assert_raises(InvasionStudio::Error) { @history.reserve(both) }
    @history.reserve(@history.fingerprints([copy]))
  end

  def test_failed_attempt_can_be_released_without_erasing_prior_history
    fingerprints = @history.fingerprints([@source])
    inserted = @history.reserve(fingerprints)
    @history.release(inserted)
    @history.reserve(fingerprints)
    inserted = @history.reserve(fingerprints, allow_reimport: true)
    @history.release(inserted)
    assert_raises(InvasionStudio::Error) { @history.reserve(fingerprints) }
  end
end
