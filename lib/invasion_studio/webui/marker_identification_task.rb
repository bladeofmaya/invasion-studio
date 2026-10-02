# frozen_string_literal: true

module InvasionStudio
  module Webui
    class MarkerIdentificationTask
      class Busy < Error; end

      def initialize(project, executor: ->(&job) { Thread.new(&job) },
                     video_factory: ->(path, options) { Video.new(path, options) }, dependency_check: nil)
        @project, @executor, @video_factory = project, executor, video_factory
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

      def start(clip_id)
        fingerprint = @project.clip_fingerprint(clip_id)
        clip = @project.find_clip(clip_id)
        path = @project.resolve_clip_path(clip)
        options = ExtractionRequest.validate_options(@project.extraction_settings).merge(no_cache: true, quiet: true)
        initial = @mutex.synchronize do
          raise Busy, 'Marker identification is already running' if @state[:status] == 'running'

          @state = { id: SecureRandom.uuid, clip_id: clip_id, status: 'running', current: nil, total: nil }
          @state.dup
        end
        begin
          @executor.call { run(clip_id, path, fingerprint, options) }
        rescue StandardError => error
          update(status: 'failed', error: error.message)
          raise
        end
        initial
      end

      private

      def update(**values)
        @mutex.synchronize { @state.merge!(values) }
      end

      def run(clip_id, path, fingerprint, options)
        @dependency_check.call
        video = @video_factory.call(path, options.merge(
          progress_callback: ->(current, total) { update(current: current, total: total) }
        ))
        detector = Extraction::EventMarkers.new([video])
        segment = Scanner::Segment.new('00:00:00', path,
                                       TimeHelper.wind_forward('00:00:00', video.metadata.fetch(:duration)), path)
        markers = detector.for_segment(segment)
        added = @project.merge_detected_markers(clip_id, markers, fingerprint: fingerprint)
        update(status: 'completed', added: added)
      rescue StandardError => error
        update(status: 'failed', error: error.message)
      end
    end
  end
end
