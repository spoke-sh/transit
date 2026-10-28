Gem::Specification.new do |spec|
  spec.name = 'transit-station'
  spec.version = '0.0.1'
  spec.summary = 'Ruby handlers and scoped state over native Transit Station'
  spec.authors = ['Transit contributors']
  spec.required_ruby_version = '>= 3.4', '< 3.5'
  spec.files = Dir['lib/**/*', 'README.md', 'docs/**/*']
  spec.require_paths = ['lib']
  spec.add_dependency 'transit-client', '= 0.0.1'
  spec.add_dependency 'transit-native-station', '= 0.0.1'
  spec.add_dependency 'json', '= 2.9.1'
end
