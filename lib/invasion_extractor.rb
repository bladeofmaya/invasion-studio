require 'yaml'
require 'pry'
require 'fileutils'
require 'json'
require 'yaml'
require 'digest'
require 'tmpdir'
require 'time'

# require_relative "invasion_extractor/frame"
# require_relative "invasion_extractor/clip"
# require_relative "invasion_extractor/video"
# require_relative "invasion_extractor/ocr"
# require_relative "invasion_extractor/processor"
# require_relative "invasion_extractor/invasion_scanner"
# require_relative "invasion_extractor/version"
# require_relative "invasion_extractor/time_shifter"

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
end
