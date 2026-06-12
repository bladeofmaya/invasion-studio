require 'json'
require 'fileutils'

module InvasionExtractor
  class Project
    VIDEO_EXTENSIONS = %w[.mp4 .mkv .avi .mov .webm .flv .wmv .m4v .mpeg .mpg].freeze

    attr_reader :folder_path, :data

    def initialize(folder_path)
      @folder_path = File.expand_path(folder_path)
      @project_file = File.join(@folder_path, 'project.json')
      @data = load_or_initialize
      sync_clips!
    end

    def clips
      @data['clips'].select { |c| !c['deleted'] }
    end

    def all_clips
      @data['clips']
    end

    def deleted_clips
      @data['clips'].select { |c| c['deleted'] }
    end

    def groups
      @data['groups'] || []
    end

    def create_group(name)
      return false if groups.any? { |g| g['name'] == name }

      @data['groups'] ||= []
      @data['groups'] << { 'name' => name, 'clip_ids' => [] }
      save!
      true
    end

    def rename_group(old_name, new_name)
      return false if old_name == new_name
      return false if groups.any? { |g| g['name'] == new_name }

      group = @data['groups'].find { |g| g['name'] == old_name }
      return false unless group

      group['name'] = new_name
      save!
      true
    end

    def delete_group(name)
      @data['groups'].reject! { |g| g['name'] == name }
      save!
    end

    def add_clip_to_group(group_name, clip_id)
      group = @data['groups'].find { |g| g['name'] == group_name }
      return false unless group

      group['clip_ids'] << clip_id unless group['clip_ids'].include?(clip_id)
      save!
      true
    end

    def remove_clip_from_group(group_name, clip_id)
      group = @data['groups'].find { |g| g['name'] == group_name }
      return false unless group

      group['clip_ids'].delete(clip_id)
      save!
      true
    end

    def reorder_group(group_name, old_index, new_index)
      group = @data['groups'].find { |g| g['name'] == group_name }
      return false unless group

      clip_ids = group['clip_ids']
      return false if old_index < 0 || old_index >= clip_ids.length
      return false if new_index < 0 || new_index >= clip_ids.length

      id = clip_ids.delete_at(old_index)
      clip_ids.insert(new_index, id)
      save!
      true
    end

    def update_note(clip_id, note)
      clip = find_clip(clip_id)
      return false unless clip

      clip['note'] = note
      save!
      true
    end

    def update_rating(clip_id, rating)
      clip = find_clip(clip_id)
      return false unless clip

      clip['rating'] = rating.to_i.clamp(0, 5)
      save!
      true
    end

    def delete_clip(clip_id)
      clip = find_clip(clip_id)
      return false unless clip

      source_path = clip['path']
      if File.exist?(source_path)
        trash_dir = File.join(@folder_path, '.trashed')
        FileUtils.mkdir_p(trash_dir)
        FileUtils.mv(source_path, File.join(trash_dir, clip['filename']))
      end

      clip['deleted'] = true
      save!
      true
    end

    def restore_clip(clip_id)
      clip = find_clip(clip_id)
      return false unless clip

      trash_path = File.join(@folder_path, '.trashed', clip['filename'])
      source_path = clip['path']

      if File.exist?(trash_path)
        FileUtils.mv(trash_path, source_path)
      end

      clip['deleted'] = false
      save!
      true
    end

    def group_clips(group_name)
      group = @data['groups'].find { |g| g['name'] == group_name }
      return [] unless group

      group['clip_ids'].map { |id| find_clip(id) }.compact.select { |c| !c['deleted'] }
    end

    def group_clip_paths(group_name)
      group_clips(group_name).map { |c| c['path'] }
    end

    def clip_groups(clip_id)
      @data['groups'].select { |g| g['clip_ids'].include?(clip_id) }.map { |g| g['name'] }
    end

    def find_clip(clip_id)
      @data['clips'].find { |c| c['id'] == clip_id }
    end

    def save!
      @data['updated_at'] = Time.now.iso8601
      File.write(@project_file, JSON.pretty_generate(@data))
    end

    private

    def load_or_initialize
      if File.exist?(@project_file)
        JSON.parse(File.read(@project_file))
      else
        {
          'project' => File.basename(@folder_path),
          'created_at' => Time.now.iso8601,
          'updated_at' => Time.now.iso8601,
          'clips' => [],
          'groups' => [
            { 'name' => 'Video 1', 'clip_ids' => [] }
          ]
        }
      end
    end

    def sync_clips!
      disk_files = discover_video_files
      known_filenames = @data['clips'].map { |c| c['filename'] }

      # Add new clips found on disk
      disk_files.each do |path|
        filename = File.basename(path)
        next if known_filenames.include?(filename)

        @data['clips'] << {
          'id' => File.basename(filename, '.*'),
          'filename' => filename,
          'path' => path,
          'note' => '',
          'rating' => 0,
          'deleted' => false
        }
      end

      # Ensure all clips have a rating field
      @data['clips'].each do |clip|
        clip['rating'] = 0 unless clip.key?('rating')
      end

      # Remove entries for files that no longer exist anywhere
      @data['clips'].reject! do |clip|
        path = clip['path']
        trash_path = File.join(@folder_path, '.trashed', clip['filename'])
        !File.exist?(path) && !File.exist?(trash_path)
      end

      save!
    end

    def discover_video_files
      Dir.glob(File.join(@folder_path, '*'))
         .select { |f| VIDEO_EXTENSIONS.include?(File.extname(f).downcase) }
         .sort
    end
  end
end
