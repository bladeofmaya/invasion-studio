require 'yaml'
require 'pry'
require 'fileutils'
require 'json'
require 'yaml'
require 'digest'
require 'tmpdir'
require 'time'

require_relative "helpers/time_shifter"

require_relative "invasion_cutter/frame"
require_relative "invasion_cutter/clip"
require_relative "invasion_cutter/video"
require_relative "invasion_cutter/ocr"
require_relative "invasion_cutter/processor"
require_relative "invasion_cutter/invasion_scanner"
require_relative "invasion_cutter/version"

module InvasionCutter
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
end
