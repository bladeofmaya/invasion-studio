Gem::Specification.new do |spec|
  spec.name          = "invasion_extractor"
  spec.version       = "0.2.0"
  spec.authors       = ["Blade of Maya"]
  spec.email         = ["hey@bladeofmaya.com"]

  spec.summary       = %q{Scans multiple video files for the start and end of invasions and creates signle clips.}
  spec.description   = %q{Longer description of your gem}
  spec.homepage      = "https://github.com/bladeofmaya/invasion_extractor"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*", "MIT-LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.executables = ["invasion_extractor"]

  spec.add_dependency "rtesseract", "~> 3.1.3"
  spec.add_dependency "parallel", "~> 1.25"
  spec.add_dependency "optparse", "~> 0.5"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "minitest", "~> 5.16"
  spec.add_development_dependency "pry", "~> 0.14"
  spec.add_development_dependency "rake", "~> 13.0"
end
