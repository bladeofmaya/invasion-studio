require 'test_helper'
require 'net/http'
require 'open3'
require 'timeout'

class TestWebuiProcess < Minitest::Test
  def test_ephemeral_port_health_and_sigterm_shutdown
    project = Dir.mktmpdir
    command = [Gem.ruby, File.expand_path('../bin/invasion-studio', __dir__),
               '--quiet', 'webui', '--port', '0', project]
    stdin, stdout, stderr, wait_thread = Open3.popen3(*command)
    stdin.close

    ready = Timeout.timeout(15) do
      loop do
        parsed = JSON.parse(stdout.readline) rescue nil
        break parsed if parsed&.fetch('event', nil) == 'ready'
      end
    end
    response = Net::HTTP.get_response(URI("http://127.0.0.1:#{ready.fetch('port')}/api/health"))

    assert_equal 'ready', ready['event']
    assert_equal '200', response.code
    assert_equal 'ok', JSON.parse(response.body)['status']

    Process.kill('TERM', wait_thread.pid)
    status = Timeout.timeout(10) { wait_thread.value }
    assert status.success?, "#{status.inspect}: #{stderr.read}"
  ensure
    Process.kill('KILL', wait_thread.pid) if wait_thread&.alive?
    FileUtils.rm_rf(project) if project
    stdout&.close
    stderr&.close
  end

  def test_parent_watchdog_stops_server_when_parent_disappears
    project = Dir.mktmpdir
    parent_pid = Process.spawn(Gem.ruby, '-e', 'sleep 2')
    command = [Gem.ruby, File.expand_path('../bin/invasion-studio', __dir__),
               '--quiet', 'webui', '--port', '0', '--parent-pid', parent_pid.to_s, project]
    stdin, stdout, stderr, wait_thread = Open3.popen3(*command)
    stdin.close

    ready = read_ready(stdout)
    assert_equal 'ready', ready['event']
    Process.wait(parent_pid)

    status = Timeout.timeout(10) { wait_thread.value }
    assert status.success?, "#{status.inspect}: #{stderr.read}"
  ensure
    Process.kill('KILL', parent_pid) if parent_pid && process_alive?(parent_pid)
    Process.kill('KILL', wait_thread.pid) if wait_thread&.alive?
    FileUtils.rm_rf(project) if project
    stdout&.close
    stderr&.close
  end

  private

  def read_ready(stdout)
    Timeout.timeout(15) do
      loop do
        parsed = JSON.parse(stdout.readline) rescue nil
        return parsed if parsed&.fetch('event', nil) == 'ready'
      end
    end
  end

  def process_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end
end
