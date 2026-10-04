#!/usr/bin/env ruby
# frozen_string_literal: true
require 'bundler'
require 'json'
require_relative 'runtime_dependencies'

stage = ARGV.fetch(0)
versions = DesktopPackaging.runtime_dependencies(Bundler.load.specs, 'invasion-studio')
# Tebako 2 packages a Gemfile application. Keep the complete runtime closure
# pinned, excluding development gems and the repository's path dependency.
File.write(File.join(stage, 'Gemfile'), DesktopPackaging.gemfile(versions))
File.write(File.join(stage, 'desktop-entry.rb'), <<~RUBY)
  ENV['BUNDLE_GEMFILE'] = File.expand_path('Gemfile', __dir__)
  require 'bundler/setup'
  load File.expand_path('bin/invasion-studio', __dir__)
RUBY
File.write(File.join(stage, 'desktop-dependencies.json'), JSON.pretty_generate(versions) + "\n")
