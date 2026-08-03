require 'test_helper'
require 'rexml/document'
require 'rexml/xpath'
require 'tmpdir'

class TestKdenliveDocument < Minitest::Test
  METADATA = { duration: 10.0, width: 1920, height: 1080, fps: 30 }.freeze

  def setup
    @folder = Dir.mktmpdir(['kdenlive & project', ''])
    exporter = InvasionStudio::KdenliveExporter.new(@folder, quiet: true)
    xml = exporter.build_project(File.join(@folder, 'combined & final.mp4'), METADATA)
    @document = REXML::Document.new(xml)
  end

  def teardown
    FileUtils.rm_rf(@folder)
  end

  def test_profile_contract
    profile = REXML::XPath.first(@document, '/mlt/profile')

    assert_equal '2560', profile.attributes['width']
    assert_equal '1440', profile.attributes['height']
    assert_equal '30', profile.attributes['frame_rate_num']
    assert_equal '1', profile.attributes['frame_rate_den']
    assert_equal '16', profile.attributes['display_aspect_num']
    assert_equal '9', profile.attributes['display_aspect_den']
  end

  def test_media_chain_and_stream_mapping_contract
    chains = REXML::XPath.match(@document, '/mlt/chain')

    assert_equal %w[chain0 chain1 chain2 chain3 chain4 chain5], chains.map { |node| node.attributes['id'] }
    assert_equal %w[4 3 2 1], chains.first(4).map { |chain| property(chain, 'audio_index') }
    assert_equal %w[3 2 1 0], chains.first(4).map { |chain| property(chain, 'astream') }
    assert_equal '-1', property(chains.fetch(4), 'audio_index')
    assert_equal '0', property(chains.fetch(4), 'video_index')
    assert_nil property(chains.fetch(5), 'audio_index')
  end

  def test_playlist_and_track_tractor_contract
    playlist_ids = REXML::XPath.match(@document, '/mlt/playlist').map { |node| node.attributes['id'] }
    tractor_ids = REXML::XPath.match(@document, '/mlt/tractor').map { |node| node.attributes['id'] }

    (0..11).each { |index| assert_includes playlist_ids, "playlist#{index}" }
    (0..5).each { |index| assert_includes tractor_ids, "tractor#{index}" }
    assert_includes tractor_ids, 'tractor_project'
  end

  def test_sequence_uuid_relationship_contract
    sequence = REXML::XPath.match(@document, '/mlt/tractor').find do |tractor|
      property(tractor, 'kdenlive:uuid')
    end
    sequence_uuid = sequence.attributes['id']
    project_track = REXML::XPath.first(@document, "/mlt/tractor[@id='tractor_project']/track")

    assert_match(/\A\{[0-9a-f-]{36}\}\z/, sequence_uuid)
    assert_equal sequence_uuid, property(sequence, 'kdenlive:uuid')
    assert_equal sequence_uuid, property(sequence, 'kdenlive:sequenceproperties.documentuuid')
    assert_equal sequence_uuid, project_track.attributes['producer']
  end

  def test_dynamic_paths_are_xml_escaped_and_round_trip
    root = REXML::XPath.first(@document, '/mlt')
    resource = property(REXML::XPath.first(@document, "/mlt/chain[@id='chain0']"), 'resource')

    assert_equal File.expand_path(@folder), root.attributes['root']
    assert_equal 'combined & final.mp4', resource
  end

  def test_timecode_and_duration_contract
    chain = REXML::XPath.first(@document, "/mlt/chain[@id='chain0']")
    sequence = REXML::XPath.match(@document, '/mlt/tractor').find do |tractor|
      property(tractor, 'kdenlive:uuid')
    end

    assert_equal '00:00:10.000', chain.attributes['out']
    assert_equal '300', property(chain, 'length')
    assert_equal '300', property(sequence, 'kdenlive:maxduration')
  end

  def test_timeline_guides_mark_chapter_starts_with_titles
    chapters = [
      { title: 'Opening & setup', start_time: 0.0, end_time: 4.0 },
      { title: 'Final invasion', start_time: 4.0, end_time: 10.0 }
    ]
    exporter = InvasionStudio::KdenliveExporter.new(@folder, quiet: true)
    xml = exporter.build_project(File.join(@folder, 'combined.mp4'), METADATA, chapters: chapters)
    document = REXML::Document.new(xml)
    sequence = REXML::XPath.match(document, '/mlt/tractor').find do |tractor|
      property(tractor, 'kdenlive:uuid')
    end

    guides = JSON.parse(property(sequence, 'kdenlive:sequenceproperties.guides'))
    assert_equal [
      { 'comment' => 'Opening & setup', 'pos' => 0, 'type' => 0 },
      { 'comment' => 'Final invasion', 'pos' => 120, 'type' => 0 }
    ], guides
  end

  private

  def property(node, name)
    REXML::XPath.first(node, "property[@name='#{name}']")&.text
  end
end
