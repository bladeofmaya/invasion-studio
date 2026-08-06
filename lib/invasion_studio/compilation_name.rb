# frozen_string_literal: true

module InvasionStudio
  module CompilationName
    MAX_LENGTH = 100
    FORBIDDEN_CHARACTERS = /[<>:"\\|?*\/\x00-\x1f]/
    RESERVED_NAMES = /\A(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?\z/i

    module_function

    def valid?(name)
      value = name.to_s
      return false if value.empty? || value != value.strip
      return false if value.length > MAX_LENGTH
      return false if ['.', '..'].include?(value)
      return false if value.match?(FORBIDDEN_CHARACTERS)
      return false if value.end_with?('.', ' ')
      return false if value.match?(RESERVED_NAMES)

      true
    end

    def validate!(name)
      return name if valid?(name)

      raise Error, 'Compilation name is not a valid portable folder name'
    end

    def identity(name)
      name.to_s.unicode_normalize(:nfc).downcase
    end
  end
end
