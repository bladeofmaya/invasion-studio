require 'yaml'
require 'fileutils'
require 'json'
require 'tmpdir'
require 'time'
require 'rtesseract'
require 'parallel'

require_relative "invasion_extractor/version"
require_relative "invasion_extractor/engine"
require_relative "invasion_extractor/video"
require_relative "invasion_extractor/frame"
require_relative "invasion_extractor/ocr_worker"

require_relative "invasion_extractor/scanner"
require_relative "invasion_extractor/clip"
require_relative "invasion_extractor/time_helper"

module InvasionExtractor
  class Error < StandardError; end

  def self.check_tesseract_installed
    system("tesseract --version > /dev/null 2>&1")
  end

  def self.ensure_tesseract_installed
    unless check_tesseract_installed
      raise "Tesseract is not installed. Please install it before using this gem. " \
            "Visit https://github.com/tesseract-ocr/tesseract for installation instructions."
    end
  end

  def self.check_ffmpeg_installed
    system("ffmpeg -version > /dev/null 2>&1")
  end

  def self.ensure_ffmpeg_installed
    unless check_ffmpeg_installed
      raise "FFmpeg is not installed. Please install it before using this gem. " \
            "Visit https://ffmpeg.org/download.html for installation instructions."
    end
  end
end
