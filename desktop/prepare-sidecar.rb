#!/usr/bin/env ruby
# frozen_string_literal: true
require 'bundler'
require 'json'
require_relative 'runtime_dependencies'

stage = ARGV.fetch(0)
versions = DesktopPackaging.runtime_dependencies(Bundler.load.specs, 'invasion-studio')
# Tebako's base runtime contains additional gems. Exact requirements in the
# desktop-only gemspec prevent RubyGems activating an untested newer version.
File.open(File.join(stage, 'invasion-studio.gemspec'), 'a') do |file|
  file.puts '.tap do |spec|'
  file.puts '  spec.dependencies.clear'
  versions.each { |name, version| file.puts "  spec.add_dependency #{name.inspect}, #{"= #{version}".inspect}" }
  file.puts 'end'
end
File.write(File.join(stage, 'desktop-dependencies.json'), JSON.pretty_generate(versions) + "\n")
