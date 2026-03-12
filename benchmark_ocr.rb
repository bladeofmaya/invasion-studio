#!/usr/bin/env ruby
# Benchmark script for OCR providers

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'invasion_extractor'
require 'benchmark'

puts '=' * 60
puts 'OCR Provider Benchmark'
puts '=' * 60

# Extract sample frames from the video at key timestamps
# Based on actual detected text in the video
sample_frames = [
  { name: 'first_inv_end', ts: '00:01:44', expect: %w[returning world defeated] },
  { name: 'second_inv_start', ts: '00:02:42', expect: %w[invading world] },
  { name: 'second_inv_target', ts: '00:03:07', expect: %w[defeat host fingers] },
  { name: 'second_inv_end', ts: '00:03:26', expect: %w[returning world] }
]

puts "\nExtracting sample frames (with crop)..."
# For 720p video: scale=0.5 from 1440p base
# crop_width = 700 * 0.5 = 350, crop_height = 200 * 0.5 = 100
# crop_x = 950 * 0.5 = 475, crop_y = 960 * 0.5 = 480
sample_frames.each do |frame|
  cmd = "ffmpeg -y -ss #{frame[:ts]} -i test/samples/invasion-sample-720p.mp4 -filter_complex 'crop=350:100:475:480' -frames:v 1 -update 1 tmp/benchmark_#{frame[:name]}.jpg 2>/dev/null"
  system(cmd)
  puts "  Extracted: #{frame[:name]} at #{frame[:ts]}"
end

# Initialize providers - add OllamaProvider if available
providers = [InvasionExtractor::OCR::TesseractProvider.new]

begin
  ollama_provider = InvasionExtractor::OCR::OllamaProvider.new(model: 'llava:7b')
  providers << ollama_provider
  puts "\n✓ OllamaProvider (llava:7b) added to benchmark"
rescue StandardError => e
  puts "\n✗ OllamaProvider unavailable: #{e.message}"
end

puts "\n" + '=' * 60
puts 'Running Benchmarks'
puts '=' * 60

results = {}

providers.each do |provider|
  puts "\n#{provider.name.upcase} Provider:"
  puts '-' * 40

  provider_results = { times: [], texts: [], accuracy: 0 }

  sample_frames.each do |frame_info|
    frame_path = "tmp/benchmark_#{frame_info[:name]}.jpg"

    # Run OCR and time it
    text = nil
    time = Benchmark.measure do
      text = provider.recognize(frame_path)
    end

    elapsed = time.real
    provider_results[:times] << elapsed
    provider_results[:texts] << { name: frame_info[:name], text: text }

    # Check accuracy
    found_expected = frame_info[:expect].any? { |exp| text.downcase.include?(exp.downcase) }
    accuracy = frame_info[:expect].empty? || found_expected

    status = accuracy ? '✓' : '✗'
    puts "  #{status} #{frame_info[:name]}: #{elapsed.round(3)}s"
    puts "    Text: #{text[0..80].inspect}"
    puts "    Expected: #{frame_info[:expect].join(', ')}" unless frame_info[:expect].empty?
  end

  avg_time = provider_results[:times].sum / provider_results[:times].size
  total_time = provider_results[:times].sum

  provider_results[:avg_time] = avg_time
  provider_results[:total_time] = total_time

  puts "\n  Summary:"
  puts "    Average: #{avg_time.round(3)}s per frame"
  puts "    Total: #{total_time.round(3)}s for #{sample_frames.size} frames"

  results[provider.name] = provider_results
end

puts "\n" + '=' * 60
puts 'Benchmark Comparison'
puts '=' * 60
if results.size > 1
  puts "\nProvider Comparison:"
  results.each do |name, data|
    puts "  #{name.capitalize}: #{data[:avg_time].round(3)}s avg, #{data[:total_time].round(3)}s total"
  end

  if results['ollama'] && results['tesseract']
    speedup = results['ollama'][:avg_time] / results['tesseract'][:avg_time]
    puts "\n  Tesseract is #{speedup.round(1)}x faster than Ollama (llava:7b)"
  end
end

puts "\n" + '=' * 60
puts 'Benchmark Complete'
puts '=' * 60
