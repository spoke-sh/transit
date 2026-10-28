Gem::Specification.new do |spec|
  spec.name = 'transit-sdk-examples'
  spec.version = '0.0.1'
  spec.summary = 'Public Transit Ruby counter and query examples'
  spec.authors = ['Transit contributors']
  spec.required_ruby_version = '>= 3.4', '< 3.5'
  spec.files = Dir['lib/**/*.rb', 'bin/*', 'README.md']
  spec.require_paths = ['lib']
  spec.bindir = 'bin'
  spec.executables = ['transit-ruby-counter']
  spec.add_dependency 'transit-client', '= 0.0.1'
  spec.add_dependency 'transit-station', '= 0.0.1'
  spec.add_dependency 'json', '= 2.9.1'
end
