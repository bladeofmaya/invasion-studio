# frozen_string_literal: true

module InvasionStudio
  module Paths
    module_function

    def config_dir
      File.join(xdg_home("XDG_CONFIG_HOME", ".config"), "invasion-studio")
    end

    def cache_dir
      File.join(xdg_home("XDG_CACHE_HOME", ".cache"), "invasion-studio")
    end

    def data_dir
      File.join(xdg_home("XDG_DATA_HOME", File.join(".local", "share")), "invasion-studio")
    end

    def state_dir
      File.join(xdg_home("XDG_STATE_HOME", File.join(".local", "state")), "invasion-studio")
    end

    def xdg_home(environment_variable, fallback)
      configured_path = ENV[environment_variable]
      return configured_path if configured_path && File.absolute_path(configured_path) == configured_path

      File.join(Dir.home, fallback)
    end
    private_class_method :xdg_home
  end
end
