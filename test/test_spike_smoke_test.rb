# frozen_string_literal: true

require 'test_helper'
require 'json'
require_relative '../desktop/spike/support/smoke_test'

class TestSpikeSmokeTest < Minitest::Test
  Response = Data.define(:code, :body)

  class FakeHttp
    attr_reader :uploads

    def initialize(responses)
      @responses = responses
      @uploads = []
    end

    def get(path)
      @responses.fetch([:get, path])
    end

    def upload(path, file_path)
      @uploads << [path, file_path]
      @responses.fetch([:upload, path])
    end
  end

  def setup
    @folder = Dir.mktmpdir
    @clip_path = File.join(@folder, 'sample.mp4')
    File.write(@clip_path, 'sample')
  end

  def teardown
    FileUtils.rm_rf(@folder)
  end

  def test_verifies_shell_upload_api_and_stream
    http = FakeHttp.new(
      [:get, '/api/health'] => Response.new('200', JSON.generate(status: 'ok', version: '0.8.0')),
      [:get, '/'] => Response.new('200', '<title>Invasion Studio</title>'),
      [:get, '/assets/app.css'] => Response.new('200', 'css'),
      [:get, '/assets/app.js'] => Response.new('200', 'js'),
      [:upload, '/api/upload'] => Response.new('200', JSON.generate(imported: 1, clips: ['clips/sample'])),
      [:get, '/api/clip/clips%2Fsample'] => Response.new('200', JSON.generate(
        id: 'clips/sample', filename: 'sample.mp4'
      )),
      [:get, '/clip/sample.mp4'] => Response.new('206', 'bytes')
    )

    evidence = InvasionStudio::Spike::SmokeTest.new(http: http).run(@clip_path)

    assert_equal ['clips/sample'], evidence.fetch(:clip_ids)
    assert_equal [['/api/upload', @clip_path]], http.uploads
    assert evidence.fetch(:checks).values.all?
  end

  def test_rejects_an_upload_without_exactly_one_clip
    http = FakeHttp.new(
      [:get, '/api/health'] => Response.new('200', JSON.generate(status: 'ok', version: '0.8.0')),
      [:get, '/'] => Response.new('200', 'Invasion Studio'),
      [:get, '/assets/app.css'] => Response.new('200', 'css'),
      [:get, '/assets/app.js'] => Response.new('200', 'js'),
      [:upload, '/api/upload'] => Response.new('200', JSON.generate(imported: 0, clips: []))
    )

    error = assert_raises(InvasionStudio::Spike::SmokeTest::Failure) do
      InvasionStudio::Spike::SmokeTest.new(http: http).run(@clip_path)
    end

    assert_match(/exactly one clip/, error.message)
  end
end
