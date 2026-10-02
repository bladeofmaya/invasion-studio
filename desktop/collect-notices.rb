#!/usr/bin/env ruby
# frozen_string_literal: true
require 'fileutils'
require 'json'
require 'pathname'

root, destination = ARGV
abort 'Usage: collect-notices.rb EXTRACTED_SIDECAR OUTPUT' unless destination
FileUtils.mkdir_p(destination)
root = Pathname.new(root)
Dir.glob(root.join('**/*'), File::FNM_DOTMATCH).sort.each do |file|
  next unless File.file?(file)
  next unless File.basename(file).match?(/(?:license|copying|copyright|notice)/i)

  relative = Pathname.new(file).relative_path_from(root)
  target = File.join(destination, relative)
  FileUtils.mkdir_p(File.dirname(target))
  FileUtils.cp(file, target)
end
specs = Dir.glob(root.join('lib/ruby/gems/*/specifications/**/*.gemspec')).sort.filter_map do |file|
  spec = Gem::Specification.load(file)
  next unless spec

  { name: spec.name, version: spec.version.to_s, licenses: spec.licenses }
end
File.write(File.join(destination, 'inventory.json'), JSON.pretty_generate(specs) + "\n")
# Tebako runtime embeds its BSD notice in the source header.
Dir.glob(root.join('lib/ruby/gems/*/gems/tebako-runtime-*/tebako-runtime.gemspec')).each do |file|
  FileUtils.cp(file, File.join(destination, 'tebako-runtime-notice.txt'))
end
