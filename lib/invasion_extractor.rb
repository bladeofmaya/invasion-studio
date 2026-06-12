require 'yaml'
require 'fileutils'
require 'json'
require 'tmpdir'
require 'time'
require 'rtesseract'
require 'parallel'
require 'etc'
require 'tempfile'
require 'tty-progressbar'

require_relative 'invasion_extractor/version'
require_relative 'invasion_extractor/engine'
require_relative 'invasion_extractor/video'
require_relative 'invasion_extractor/frame'
require_relative 'invasion_extractor/ocr_worker'
require_relative 'invasion_extractor/gpu_detector'
require_relative 'invasion_extractor/scanner'
require_relative 'invasion_extractor/clip'
require_relative 'invasion_extractor/time_helper'

# OCR Providers
require_relative 'invasion_extractor/ocr/provider'
require_relative 'invasion_extractor/ocr/tesseract_provider'

# CLI and Commands
require_relative 'invasion_extractor/cli'
require_relative 'invasion_extractor/commands/base'
require_relative 'invasion_extractor/commands/extract'
require_relative 'invasion_extractor/commands/export_kdenlive'
require_relative 'invasion_extractor/commands/concat'
require_relative 'invasion_extractor/commands/webui'

# WebUI
require_relative 'invasion_extractor/webui/server'

# Project and Exporters
require_relative 'invasion_extractor/project'
require_relative 'invasion_extractor/project_exporter'
require_relative 'invasion_extractor/kdenlive_exporter'

module InvasionExtractor
  class Error < StandardError; end

  CACHE_DIR = '/dev/shm/invasion_extractor_cache'

  module VideoHasher
    def self.hash(path)
      require 'digest'
      base = File.basename(path, '.*')
      path_hash = Digest::MD5.hexdigest(File.expand_path(path))[0..7]
      "#{base}-#{path_hash}"
    end
  end

  def self.check_tesseract_installed
    system('tesseract --version > /dev/null 2>&1')
  end

  def self.ensure_tesseract_installed
    return if check_tesseract_installed

    raise 'Tesseract is not installed. Please install it before using this gem. ' \
          'Visit https://github.com/tesseract-ocr/tesseract for installation instructions.'
  end

  def self.check_ffmpeg_installed
    system('ffmpeg -version > /dev/null 2>&1')
  end

  def self.ensure_ffmpeg_installed
    return if check_ffmpeg_installed

    raise 'FFmpeg is not installed. Please install it before using this gem. ' \
          'Visit https://ffmpeg.org/download.html for installation instructions.'
  end
end
