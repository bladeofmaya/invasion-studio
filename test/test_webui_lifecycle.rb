require 'test_helper'
require 'stringio'

class TestWebuiLifecycle < Minitest::Test
  FakeServer = Struct.new(:connected_ports)

  def test_reports_machine_readable_ready_event_with_bound_port
    output = StringIO.new
    lifecycle = InvasionStudio::Webui::Lifecycle.new(output: output)

    lifecycle.ready(FakeServer.new([51_234]))

    assert_equal({ 'event' => 'ready', 'port' => 51_234 }, JSON.parse(output.string))
  end

  def test_watchdog_stops_server_after_parent_disappears
    probes = [true, false]
    stopped = false
    lifecycle = InvasionStudio::Webui::Lifecycle.new(
      process_alive: ->(_pid) { probes.shift },
      sleeper: ->(_seconds) {}
    )

    lifecycle.watch_parent(1234) { stopped = true }.join

    assert stopped
  end

  def test_watchdog_is_disabled_without_parent_pid
    lifecycle = InvasionStudio::Webui::Lifecycle.new

    assert_nil lifecycle.watch_parent(nil) { flunk 'must not stop' }
  end
end
