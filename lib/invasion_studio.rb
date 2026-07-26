require 'yaml'
require 'fileutils'
require 'json'
require 'tmpdir'
require 'time'
require 'etc'
require 'tempfile'
require 'tty-progressbar'
require 'English'

module InvasionStudio
  class Error < StandardError; end
end

require_relative 'invasion_studio/version'
require_relative 'invasion_studio/paths'
require_relative 'invasion_studio/media_files'
require_relative 'invasion_studio/process_runner'
require_relative 'invasion_studio/project_schema'
require_relative 'invasion_studio/atomic_json_store'
require_relative 'invasion_studio/project_repository'
require_relative 'invasion_studio/engine'
require_relative 'invasion_studio/video'
require_relative 'invasion_studio/frame'
require_relative 'invasion_studio/ocr_worker'
require_relative 'invasion_studio/gpu_detector'
require_relative 'invasion_studio/scanner'
require_relative 'invasion_studio/clip'
require_relative 'invasion_studio/time_helper'

# OCR Providers
require_relative 'invasion_studio/ocr/provider'
require_relative 'invasion_studio/ocr/tesseract_provider'

# CLI and Commands
require_relative 'invasion_studio/commands/base'
require_relative 'invasion_studio/commands/extract'
require_relative 'invasion_studio/commands/export_kdenlive'
require_relative 'invasion_studio/commands/concat'
require_relative 'invasion_studio/commands/webui'
require_relative 'invasion_studio/cli'

# WebUI
require_relative 'invasion_studio/webui/server'

# Project and Exporters
require_relative 'invasion_studio/project'
require_relative 'invasion_studio/project_exporter'
require_relative 'invasion_studio/kdenlive_exporter'

module InvasionStudio
  module VideoHasher
    def self.hash(path)
      require 'digest'
      base = File.basename(path, '.*')
      path_hash = Digest::MD5.hexdigest(File.expand_path(path))[0..7]
      "#{base}-#{path_hash}"
    end
  end

  def self.check_tesseract_installed
    ProcessRunner.new.capture('tesseract', '--version').success?
  rescue Error
    false
  end

  def self.ensure_tesseract_installed
    return if check_tesseract_installed

    raise 'Tesseract is not installed. Please install it before using this gem. ' \
          'Visit https://github.com/tesseract-ocr/tesseract for installation instructions.'
  end

  def self.check_ffmpeg_installed
    ProcessRunner.new.capture('ffmpeg', '-version').success?
  rescue Error
    false
  end

  def self.ensure_ffmpeg_installed
    return if check_ffmpeg_installed

    raise 'FFmpeg is not installed. Please install it before using this gem. ' \
          'Visit https://ffmpeg.org/download.html for installation instructions.'
  end
end
