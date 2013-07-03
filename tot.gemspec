# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tot/version'

Gem::Specification.new do |spec|
  spec.name          = "tot"
  spec.version       = Tot::VERSION
  spec.authors       = ["Shohei Fujii"]
  spec.email         = ["fujii.shohei@gmail.com"]
  spec.description   = %q{Todo on Terminal}
  spec.summary       = %q{Manage your todo in your terminal}
  spec.homepage      = "https://ompugao.github.io/"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "thor"
end
