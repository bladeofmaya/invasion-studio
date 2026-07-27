require_relative 'lib/invasion_studio/version'

Gem::Specification.new do |spec|
  spec.name          = 'invasion-studio'
  spec.version       = InvasionStudio::VERSION
  spec.authors       = ['Blade of Maya']
  spec.email         = ['hey@bladeofmaya.com']

  spec.required_ruby_version = '>= 3.3.3'

  spec.summary       = 'Scans multiple video files for the start and end of invasions and creates single clips.'
  spec.description   = 'Detect, review, organize, and export Elden Ring invasion clips.'
  spec.homepage      = 'https://bladeofmaya.com'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*', 'MIT-LICENSE', 'README.md', 'THIRD_PARTY_LICENSES.md']
  spec.require_paths = ['lib']

  spec.executables = ['invasion-studio']

  spec.add_dependency 'optparse', '~> 0.5'
  spec.add_dependency 'tty-progressbar', '~> 0.18'
  spec.add_dependency 'sinatra', '~> 4.1'
  spec.add_dependency 'rackup', '~> 2.1'
  spec.add_dependency 'puma', '~> 6.0'
  spec.add_dependency 'sequel', '~> 5.0'
  spec.add_dependency 'sqlite3', '~> 2.0'
  spec.add_dependency 'sucker_punch', '~> 3.0'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'minitest', '~> 6.0'
  spec.add_development_dependency 'pry', '~> 0.14'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rack-test', '~> 2.0'
  spec.add_development_dependency 'rexml', '~> 3.3'
end
