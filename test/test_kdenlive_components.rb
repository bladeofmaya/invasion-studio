require 'test_helper'
require 'rexml/document'
require 'rexml/xpath'

class TestKdenliveComponents < Minitest::Test
  def setup
    uuids = %w[sequence document control session].each
    @context = InvasionStudio::Kdenlive::BuildContext.new(
      folder_path: '/tmp/project & files',
      video_path: '/tmp/project & files/combined & final.mp4',
      metadata: { duration: 10.0, fps: 30 },
      width: 2560,
      height: 1440,
      uuid_factory: -> { "{#{uuids.next}}" },
      clock: -> { Time.at(123.456) }
    )
  end

  def test_build_context_is_deterministic
    assert_equal 300, @context.duration_frames
    assert_equal '00:00:10.000', @context.duration_timecode
    assert_equal '00:00:10.033', @context.sequence_duration_timecode
    assert_equal '{sequence}', @context.sequence_uuid
    assert_equal '{control}', @context.control_uuid
    assert_equal '123456', @context.document_id
  end

  def test_profile_component
    node = parse_fragment(InvasionStudio::Kdenlive::Profile.new(@context).to_xml)

    assert_equal '2560', node.attributes['width']
    assert_equal '1440', node.attributes['height']
    assert_equal '16', node.attributes['display_aspect_num']
    assert_equal '9', node.attributes['display_aspect_den']
  end

  def test_media_chains_component
    root = parse_root(InvasionStudio::Kdenlive::MediaChains.new(@context).to_xml)
    chains = REXML::XPath.match(root, 'chain')

    assert_equal 6, chains.length
    assert_equal 'combined & final.mp4', property(chains.first, 'resource')
    assert_equal %w[4 3 2 1], chains.first(4).map { |chain| property(chain, 'audio_index') }
    assert_equal '{control}', property(chains.first, 'kdenlive:control_uuid')
  end

  def test_timeline_tracks_component
    root = parse_root(InvasionStudio::Kdenlive::TimelineTracks.new(@context).to_xml)

    assert_equal 12, REXML::XPath.match(root, 'playlist').length
    assert_equal 6, REXML::XPath.match(root, 'tractor').length
    assert_equal 12, REXML::XPath.match(root, "tractor[starts-with(@id, 'tractor')]/filter").length
    assert_equal 'playlist8', REXML::XPath.first(root, "tractor[@id='tractor4']/track").attributes['producer']
  end

  def test_sequence_component
    node = parse_fragment(InvasionStudio::Kdenlive::Sequence.new(@context).to_xml)

    assert_equal '{sequence}', node.attributes['id']
    assert_equal '300', property(node, 'kdenlive:maxduration')
    assert_equal 7, REXML::XPath.match(node, 'track').length
    assert_equal %w[mix mix mix mix qtblend qtblend],
                 REXML::XPath.match(node, 'transition').map { |transition| property(transition, 'mlt_service') }
    assert_equal %w[filter12 filter13], REXML::XPath.match(node, 'filter').map { |filter| filter.attributes['id'] }
  end

  def test_project_bin_component
    root = parse_root(InvasionStudio::Kdenlive::ProjectBin.new(@context).to_xml)
    bin = REXML::XPath.first(root, "playlist[@id='main_bin']")
    project_track = REXML::XPath.first(root, "tractor[@id='tractor_project']/track")

    assert_equal '123456', property(bin, 'kdenlive:docproperties.documentid')
    assert_equal '{document}', property(bin, 'kdenlive:docproperties.uuid')
    assert_equal '{session}', property(bin, 'kdenlive:docproperties.sessionid')
    assert_equal '{sequence}', project_track.attributes['producer']
    assert_equal 2, REXML::XPath.match(bin, 'entry').length
  end

  def test_document_layout_follows_probed_audio_stream_count
    [0, 1, 3].each do |audio_stream_count|
      context = build_context(audio_stream_count: audio_stream_count)
      root = parse_root(
        InvasionStudio::Kdenlive::MediaChains.new(context).to_xml +
        InvasionStudio::Kdenlive::TimelineTracks.new(context).to_xml +
        InvasionStudio::Kdenlive::Sequence.new(context).to_xml +
        InvasionStudio::Kdenlive::ProjectBin.new(context).to_xml
      )

      assert_equal audio_stream_count + 2, REXML::XPath.match(root, 'chain').length
      assert_equal audio_stream_count + 3,
                   REXML::XPath.match(root, "tractor[not(@id='tractor_project')]").length
      assert_equal audio_stream_count,
                   REXML::XPath.match(root, 'chain/property[@name="audio_index" and text() != "-1"]').length
      assert_equal "chain#{audio_stream_count + 1}",
                   REXML::XPath.match(root, "playlist[@id='main_bin']/entry").last.attributes['producer']
    end
  end

  private

  def parse_fragment(xml)
    REXML::Document.new(xml).root
  end

  def parse_root(xml)
    REXML::Document.new("<root>#{xml}</root>").root
  end

  def property(node, name)
    REXML::XPath.first(node, "property[@name='#{name}']")&.text
  end

  def build_context(audio_stream_count:)
    InvasionStudio::Kdenlive::BuildContext.new(
      folder_path: '/tmp/project',
      video_path: '/tmp/project/combined.mp4',
      metadata: { duration: 10.0, fps: 30, audio_stream_count: audio_stream_count },
      width: 2560,
      height: 1440,
      uuid_factory: -> { '{uuid}' },
      clock: -> { Time.at(0) }
    )
  end
end
