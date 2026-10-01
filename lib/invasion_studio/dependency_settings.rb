# frozen_string_literal: true

module InvasionStudio
  class DependencySettings
    attr_reader :path

    def initialize(path: File.join(Paths.config_dir, 'dependencies.json'))
      @path = path
    end

    def overrides
      return {} unless File.exist?(@path)

      data = JSON.parse(File.read(@path))
      unless data.is_a?(Hash) && (data.keys - Executables::TOOLS.keys.map(&:to_s)).empty? &&
             data.values.all? { |value| value.is_a?(String) && !value.include?("\0") }
        raise Error, "Invalid dependency settings in #{@path}"
      end
      data
    rescue JSON::ParserError
      raise Error, "Invalid dependency settings in #{@path}"
    end

    def update(values)
      unless values.is_a?(Hash) && !values.empty? && (values.keys - Executables::TOOLS.keys.map(&:to_s)).empty?
        raise Error, 'Choose ffmpeg, ffprobe, or tesseract'
      end
      validated = values.to_h do |name, value|
        raise Error, "#{name}: expected an executable path" unless value.is_a?(String) && !value.include?("\0")
        value = value.strip
        unless value.empty?
          unless value.start_with?('/', '~/')
            raise Error, "#{name}: enter a full executable path, without command arguments"
          end
          value = File.expand_path(value)
          raise Error, "#{name}: file does not exist or is not executable" unless available?(value)
        end
        [name, value]
      end
      FileUtils.mkdir_p(File.dirname(@path))
      File.open(@path + '.lock', File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        merged = overrides.merge(validated).reject { |_name, value| value.empty? }
        Tempfile.create(['dependencies', '.json'], File.dirname(@path)) do |file|
          file.write(JSON.pretty_generate(merged))
          file.flush
          File.rename(file.path, @path)
        end
      end
      true
    end

    def diagnostics(environment = ENV)
      custom = overrides
      Executables::TOOLS.map do |name, variable|
        automatic = environment[variable].to_s
        automatic = name.to_s if automatic.empty?
        detected = resolve(automatic, environment)
        active = custom[name.to_s] || detected
        {
          'name' => name.to_s,
          'custom_path' => custom[name.to_s] || '',
          'detected_path' => detected,
          'active_path' => active,
          'source' => custom[name.to_s] ? 'Custom path' : (environment[variable].to_s.empty? ? 'System PATH' : variable),
          'available' => available?(active)
        }
      end
    end

    private

    def resolve(command, environment)
      return File.expand_path(command) if command.include?(File::SEPARATOR)

      environment.fetch('PATH', '').split(File::PATH_SEPARATOR).filter_map do |folder|
        candidate = File.expand_path(command, folder)
        candidate if available?(candidate)
      end.first
    end

    def available?(path)
      path && File.file?(path) && File.executable?(path) ? true : false
    end
  end
end
