# frozen_string_literal: true

module DesktopPackaging
  def self.runtime_dependencies(specifications, root)
    specs = specifications.to_h { |spec| [spec.name, spec] }
    versions = {}
    visit = lambda do |name|
      specs.fetch(name).dependencies.select { |dependency| dependency.type == :runtime }.each do |dependency|
        next if versions.key?(dependency.name)

        versions[dependency.name] = specs.fetch(dependency.name).version.to_s
        visit.call(dependency.name)
      end
    end
    visit.call(root)
    versions.sort.to_h
  end
end
