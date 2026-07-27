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
require_relative 'invasion_studio/storage/adapter'
require_relative 'invasion_studio/storage/local_disk_storage'
require_relative 'invasion_studio/database'
require_relative 'invasion_studio/database/legacy_project_importer'
require_relative 'invasion_studio/database/clip_repository'
require_relative 'invasion_studio/database/group_repository'
require_relative 'invasion_studio/database/tag_repository'
require_relative 'invasion_studio/cut_plan'
require_relative 'invasion_studio/encounter_matcher'
require_relative 'invasion_studio/clip_writer'
require_relative 'invasion_studio/extraction/reporter'
require_relative 'invasion_studio/extraction/ocr_stage'
require_relative 'invasion_studio/extraction/scan_stage'
require_relative 'invasion_studio/extraction/clip_extraction_stage'

require_relative 'invasion_studio/clip_trash'
require_relative 'invasion_studio/clip_importer'
require_relative 'invasion_studio/clip_finalizer'
require_relative 'invasion_studio/thumbnail_generator'
require_relative 'invasion_studio/workers/thumbnail_job'
require_relative 'invasion_studio/project'
require_relative 'invasion_studio/project_exporter'

require_relative 'invasion_studio/kdenlive/build_context'
require_relative 'invasion_studio/kdenlive/profile'
require_relative 'invasion_studio/kdenlive/media_chains'
require_relative 'invasion_studio/kdenlive/timeline_tracks'
require_relative 'invasion_studio/kdenlive/sequence'
require_relative 'invasion_studio/kdenlive/project_bin'
require_relative 'invasion_studio/kdenlive/document_builder'
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
require_relative 'invasion_studio/ocr/worker_policy'
require_relative 'invasion_studio/ocr/frame_discovery'
require_relative 'invasion_studio/ocr/video_metadata_probe'
require_relative 'invasion_studio/ocr/crop_geometry'
require_relative 'invasion_studio/ocr/frame_extractor'
require_relative 'invasion_studio/ocr/progress_reporter'
require_relative 'invasion_studio/ocr/ocr_pool'

# CLI and Commands
require_relative 'invasion_studio/commands/base'
require_relative 'invasion_studio/commands/extract'
require_relative 'invasion_studio/commands/export_kdenlive'
require_relative 'invasion_studio/commands/concat'
require_relative 'invasion_studio/commands/webui'
require_relative 'invasion_studio/cli'

# WebUI
require_relative 'invasion_studio/webui/json_request'
require_relative 'invasion_studio/webui/error_mapper'
require_relative 'invasion_studio/webui/file_opener'
require_relative 'invasion_studio/webui/preview_remuxer'
require_relative 'invasion_studio/webui/group_statistics'
require_relative 'invasion_studio/webui/routes/clips'
require_relative 'invasion_studio/webui/routes/groups'
require_relative 'invasion_studio/webui/routes/uploads'
require_relative 'invasion_studio/webui/routes/exports'
require_relative 'invasion_studio/webui/routes/pages'
require_relative 'invasion_studio/webui/server'

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
