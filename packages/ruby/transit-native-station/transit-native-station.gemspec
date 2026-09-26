Gem::Specification.new do |spec|
  spec.name = 'transit-native-station'
  spec.version = '0.2.0'
  spec.summary = 'Version-matched native Transit Station port'
  spec.authors = ['Transit contributors']
  spec.required_ruby_version = '>= 3.4', '< 3.5'
  spec.platform = Gem::Platform.new('x86_64-linux')
  spec.files = Dir['lib/**/*.rb', 'native/*', 'README.md']
  spec.require_paths = ['lib']
end
