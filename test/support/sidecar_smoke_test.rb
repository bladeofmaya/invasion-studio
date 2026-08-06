# frozen_string_literal: true

require 'json'
require 'uri'

module InvasionStudio
  module Packaging
    class SidecarSmokeTest
      class Failure < StandardError; end

      def initialize(http:)
        @http = http
      end

      def run(clip_path)
        checks = {}
        health = parse_json(@http.get('/api/health'), 'health API')
        checks[:health] = health['status'] == 'ok' && !health['version'].to_s.empty?
        checks[:shell] = successful?(@http.get('/'), includes: 'Invasion Studio')
        checks[:stylesheet] = successful?(@http.get('/assets/app.css'), nonempty: true)
        checks[:javascript] = successful?(@http.get('/assets/app.js'), nonempty: true)
        assert_checks!(checks)

        upload = @http.upload('/api/upload', clip_path)
        upload_data = parse_json(upload, 'upload')
        clip_ids = upload_data['clips']
        unless upload.code.to_i.between?(200, 299) && upload_data['imported'] == 1 && clip_ids&.length == 1
          raise Failure, 'upload did not import exactly one clip'
        end

        clip_id = clip_ids.first
        clip = parse_json(@http.get("/api/clip/#{URI.encode_www_form_component(clip_id)}"), 'clip API')
        checks[:clip_api] = clip['id'] == clip_id
        checks[:clip_stream] = [200, 206].include?(@http.get(
          "/clip/#{URI.encode_www_form_component(clip.fetch('filename'))}"
        ).code.to_i)
        assert_checks!(checks)

        { clip_ids: clip_ids, clip: clip, checks: checks }
      end

      private

      def successful?(response, includes: nil, nonempty: false)
        return false unless response.code.to_i.between?(200, 299)
        return false if includes && !response.body.include?(includes)
        return false if nonempty && response.body.empty?

        true
      end

      def parse_json(response, label)
        raise Failure, "#{label} request failed with HTTP #{response.code}" unless response.code.to_i.between?(200, 299)

        JSON.parse(response.body)
      rescue JSON::ParserError => e
        raise Failure, "#{label} returned invalid JSON: #{e.message}"
      end

      def assert_checks!(checks)
        failed = checks.reject { |_name, passed| passed }.keys
        raise Failure, "failed checks: #{failed.join(', ')}" unless failed.empty?
      end
    end
  end
end
