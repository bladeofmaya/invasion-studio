require 'benchmark'

module InvasionExtractor
  # Handles benchmarking and profiling of extraction operations
  class BenchmarkRunner
    attr_reader :stats, :enabled, :profile_type, :output_file

    def initialize(options = {})
      @enabled = options[:benchmark] || false
      @profile_type = options[:profile] # 'memory', 'cpu', 'all', or nil
      @output_file = options[:benchmark_output]
      @stats = initialize_stats
      @stage_timers = {}
    end

    def start_stage(stage_name)
      return unless @enabled

      @stage_timers[stage_name] = {
        start_time: Time.now,
        start_memory: current_memory
      }
    end

    def end_stage(stage_name, metadata = {})
      return unless @enabled

      timer = @stage_timers[stage_name]
      return unless timer

      end_time = Time.now
      end_memory = current_memory
      duration = end_time - timer[:start_time]
      memory_delta = end_memory - timer[:start_memory]

      @stats[:stages][stage_name] ||= {}
      @stats[:stages][stage_name][:time] = duration
      @stats[:stages][stage_name][:memory_delta_mb] = memory_delta
      @stats[:stages][stage_name].merge!(metadata)

      # Update totals
      @stats[:total_time] += duration
      @stats[:memory][:peak_mb] = [@stats[:memory][:peak_mb], end_memory].max

      duration
    end

    def record_ocr_stats(frames_processed, duration)
      return unless @enabled

      @stats[:stages][:ocr] ||= {}
      @stats[:stages][:ocr][:frames_processed] = frames_processed
      @stats[:stages][:ocr][:fps] = frames_processed / duration if duration > 0
    end

    def record_scan_stats(invasions_found)
      return unless @enabled

      @stats[:stages][:scan] ||= {}
      @stats[:stages][:scan][:invasions_found] = invasions_found
    end

    def record_extraction_stats(clips_extracted, duration)
      return unless @enabled

      @stats[:stages][:extraction] ||= {}
      @stats[:stages][:extraction][:clips_extracted] = clips_extracted
      @stats[:stages][:extraction][:clips_per_minute] = (clips_extracted / (duration / 60.0)).round(2) if duration > 0
    end

    def print_report
      return unless @enabled

      puts "\n" + "=" * 60
      puts "BENCHMARK REPORT"
      puts "=" * 60

      puts "\nTotal Time: #{format_duration(@stats[:total_time])}"
      puts "Peak Memory: #{@stats[:memory][:peak_mb].round(2)} MB"

      puts "\nStage Breakdown:"
      puts "-" * 60

      @stats[:stages].each do |stage_name, stage_stats|
        puts "\n#{stage_name.to_s.upcase}:"
        puts "  Time: #{format_duration(stage_stats[:time])}"
        puts "  Memory Delta: #{stage_stats[:memory_delta_mb].round(2)} MB" if stage_stats[:memory_delta_mb]

        # Stage-specific metrics
        case stage_name
        when :ocr
          puts "  Frames Processed: #{stage_stats[:frames_processed]}"
          puts "  Processing Rate: #{stage_stats[:fps].round(2)} fps" if stage_stats[:fps]
        when :scan
          puts "  Invasions Found: #{stage_stats[:invasions_found]}"
        when :extraction
          puts "  Clips Extracted: #{stage_stats[:clips_extracted]}"
          puts "  Clips/Minute: #{stage_stats[:clips_per_minute]}" if stage_stats[:clips_per_minute]
        end
      end

      puts "\n" + "=" * 60
    end

    def save_report
      return unless @enabled && @output_file

      File.write(@output_file, JSON.pretty_generate(@stats))
      puts "\nBenchmark report saved to: #{@output_file}"
    end

    def self.measure(options = {}, &block)
      runner = new(options)
      runner.start_stage(:total)

      begin
        result = block.call(runner)
      ensure
        runner.end_stage(:total)
        runner.print_report
        runner.save_report
      end

      result
    end

    private

    def initialize_stats
      {
        total_time: 0.0,
        stages: {},
        memory: {
          peak_mb: 0.0,
          growth: 0.0
        },
        cpu: {
          utilization: 0.0,
          cores_used: Etc.nprocessors
        },
        timestamp: Time.now.iso8601
      }
    end

    def current_memory
      # Simple memory measurement using RSS from /proc on Linux
      # or GetProcessMem gem if available
      if defined?(GetProcessMem)
        GetProcessMem.new.mb
      elsif File.exist?("/proc/#{Process.pid}/status")
        File.read("/proc/#{Process.pid}/status").match(/VmRSS:\s+(\d+)\s+kB/)[1].to_i / 1024.0 rescue 0.0
      else
        0.0
      end
    end

    def format_duration(seconds)
      if seconds < 60
        "#{seconds.round(2)}s"
      elsif seconds < 3600
        minutes = (seconds / 60).to_i
        secs = (seconds % 60).to_i
        "#{minutes}m #{secs}s"
      else
        hours = (seconds / 3600).to_i
        minutes = ((seconds % 3600) / 60).to_i
        secs = (seconds % 60).to_i
        "#{hours}h #{minutes}m #{secs}s"
      end
    end
  end
end
