# frozen_string_literal: true

require 'securerandom'

module InvasionStudio
  module Webui
    # One background extraction per server. Status survives tab changes and reloads,
    # but is deliberately not a persistent job queue.
    class ExtractionTask
      class Busy < Error; end

      def initialize(project, executor: ->(&job) { Thread.new(&job) },
                     engine_factory: ->(paths, options) { Engine.new(paths, options) },
                     dependency_check: nil)
        @project = project
        @executor = executor
        @engine_factory = engine_factory
        @dependency_check = dependency_check || -> {
          InvasionStudio.ensure_ffmpeg_installed
          InvasionStudio.ensure_tesseract_installed
        }
        @mutex = Mutex.new
        @state = { status: 'idle' }
      end

      def status
        @mutex.synchronize { @state.dup }
      end

      def start(paths:, options: {})
        request = ExtractionRequest.new(paths, options)
        initial = @mutex.synchronize do
          raise Busy, 'An extraction is already running in this project' if @state[:status] == 'running'
          @state = {
            id: SecureRandom.uuid, status: 'running', stage: 'starting',
            imported: 0, recordings: request.paths.length
          }
          @state.dup
        end
        begin
          @executor.call { run(request) }
        rescue StandardError => e
          update(status: 'failed', error: e.message)
          raise
        end
        initial
      end

      private

      def update(**values)
        @mutex.synchronize { @state.merge!(values) }
      end

      def run(request)
        @dependency_check.call
        importer = ExtractionImporter.new(@project.folder_path, project: @project)
        options = request.options.merge(
          command: 'extract', outdir: File.join(@project.folder_path, 'clips'),
          prefix: 'clip', quiet: true, min_clip_number: importer.highest_clip_number,
          reporter: ExtractionProgress.new { |**values| update(**values) }
        )
        engine = @engine_factory.call(request.paths, options)
        begin
          engine.run!
        ensure
          # A later failure must not hide clips already written successfully.
          imported = importer.record(engine.clip_extraction_stage.created)
          update(imported: imported)
          if imported.positive?
            @project.enqueue_missing_thumbnails
            @project.enqueue_missing_metadata
          end
        end
        update(status: 'completed', stage: 'done', file: nil, current: nil, total: nil)
      rescue StandardError => e
        update(status: 'failed', error: e.message, current: nil, total: nil)
      end
    end
  end
end
