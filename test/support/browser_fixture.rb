# Non-media fixture: never open a user's project or invoke media tools.
require 'invasion_studio'
module InvasionStudio
  class ProcessRunner
    def run(*) = raise('Media processing is forbidden in browser smoke checks')
    def capture(*) = raise('Media probing is forbidden in browser smoke checks')
  end
  class Project
    def enqueue_missing_thumbnails; end
    def enqueue_missing_metadata; end
  end
end
folder = ARGV.fetch(0)
project = InvasionStudio::Project.new(folder)
project.create_group('Smoke compilation')
File.write(File.join(folder, 'smoke.mp4'), 'not a video')
project.clip_repository.create('id' => 'smoke', 'filename' => 'smoke.mp4', 'path' => 'smoke.mp4', 'duration' => 60, 'title' => 'Smoke clip')
# Selection and editing remain real; loading/decoding media is explicitly excluded.
InvasionStudio::Webui::Server.before do
  halt 204 if request.path_info.start_with?('/clip/')
end
InvasionStudio::Webui::Server.run!(folder, port: 0, quiet: true)
