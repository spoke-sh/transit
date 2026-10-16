Gem::Specification.new do |spec|
  spec.name = 'transit-client'
  spec.version = '0.2.0'
  spec.summary = 'Independent typed Ruby client for Transit'
  spec.authors = ['Transit contributors']
  spec.required_ruby_version = '>= 3.4', '< 3.5'
  spec.files = Dir['lib/**/*', 'README.md', 'docs/**/*']
  spec.require_paths = ['lib']
  spec.add_dependency 'transit-native-client', '= 0.2.0'
  spec.add_dependency 'json', '= 2.9.1'
  spec.add_dependency 'tmpdir', '= 0.3.1'
  spec.add_dependency 'uri', '= 1.0.4'
end
