# frozen_string_literal: true

module InvasionStudio
  module Webui
    class Lifecycle
      POLL_INTERVAL = 1

      def initialize(output: $stdout, process_alive: nil, sleeper: nil)
        @output = output
        @process_alive = process_alive || method(:process_alive?)
        @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      end

      def ready(server)
        port = Array(server.connected_ports).first
        raise Error, 'WebUI server did not report a bound port' unless port

        @output.puts JSON.generate(event: 'ready', port: port)
        @output.flush
        port
      end

      def watch_parent(parent_pid, &stop_server)
        return unless parent_pid

        Thread.new do
          while @process_alive.call(parent_pid)
            @sleeper.call(POLL_INTERVAL)
          end
          stop_server.call
        end
      end

      def handle_signals(&stop_server)
        %w[INT TERM].each do |signal|
          Signal.trap(signal) { stop_server.call }
        end
      end

      private

      def process_alive?(pid)
        Process.kill(0, pid)
        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true
      end
    end
  end
end
