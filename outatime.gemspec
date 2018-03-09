# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'outatime/version'

Gem::Specification.new do |spec|
  spec.name          = "outatime"
  spec.version       = Outatime::VERSION
  spec.authors       = ["Justin Mazzi", "Rubem Nakamura", "Mike Boone"]
  spec.email         = ["justin@pressed.net", "rubem.nakamura@pressed.net", "mike.boone@pressed.net"]

  spec.summary       = %q{Choose versioned S3 files from a point in time.}
  spec.description   = %q{Choose file versions from a versioned S3 bucket based on a given time.}
  spec.homepage      = "https://github.com/pressednet/outatime/"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "aws-sdk", "~> 2.6", ">= 2.6.14"
  spec.add_runtime_dependency "chronic", "~> 0.10.2"
  spec.add_runtime_dependency "ruby-progressbar", "~> 1.8.1"
  spec.add_runtime_dependency "thread", "~> 0.2.2"
  spec.add_runtime_dependency "trollop", "~> 2.1.2"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "activesupport", "~> 5.1.5"
  spec.add_development_dependency "byebug"
end
