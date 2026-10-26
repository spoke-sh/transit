# frozen_string_literal: true
require 'transit/station'
require 'base64'
require 'json'

q = Transit::Station::Unified
c = Transit::Station::Catalog
endpoint, profile_path, phase, host = ARGV
profile = JSON.parse(File.binread(profile_path)).fetch('captured')
route = profile.fetch('connection')
realm = route.fetch('realm')
declaration = profile.fetch('declaration').fetch('source').fetch('table')
resource = Transit::ResourceRef.new(realm: realm, resource: declaration.fetch('scope').fetch('resource'))
scope = c::Scope.new(resource: resource, catalog: Integer(declaration.fetch('scope').fetch('catalog')))
connection = q::Connection.new(source: Transit::ProcessRef.new(realm: realm, pid: route.fetch('source')),
  resource: Transit::ResourceRef.new(realm: realm, resource: route.fetch('resource')),
  requester: Transit::ProcessRef.new(realm: realm, pid: route.fetch('requester')),
  requests: Transit::ResourceRef.new(realm: realm, resource: route.fetch('requests')))
raise 'Query progress shares the Table resource' if resource == connection.resource
seed = File.join(File.dirname(profile_path), 'ruby-capture.seed')
File.write(seed, (phase == 'prepare' ? '1d' : '3b') * 32)
File.chmod(0o600, seed)
credential = Transit::Credential.new(realm: realm, principal: route.fetch('principal'), seed_file: seed)
config = Transit::ClientConfig.new(url: endpoint, profile: :native_v1, native_host: host, timeout_ms: 10000)
tables = q::Tables.new(url: endpoint, scope: scope, branch: Integer(declaration.fetch('branch')), audience: declaration.fetch('owner'))
bundle = q::Bundle.new(data: Base64.strict_decode64(profile.fetch('bundle').fetch('base64')))
q::Client.open(config, credential, connection, tables: tables) do |client|
  if phase == 'prepare'
    raise 'Missing name resolved' unless client.lookup_table('missing_capture_input').nil?
    definition = client.lookup_table('captured_input') or raise 'Missing direct Table'
    saved = profile.fetch('capture')
    raise 'Unexpected direct cut' unless definition.partition == Integer(saved.fetch('expected').fetch('partition')) && definition.next_lsn == Integer(saved.fetch('expected').fetch('next_lsn'))
    description = client.compile_sql(definition.source, 'captured_input', 'SELECT COUNT(*) AS n FROM captured_input',
      q::Budgets.new(pages: 64, segments: 64, result_bytes: 1048576))
    sealed = client.authorize_bundle(description, capture: definition.capture(executor: saved.fetch('executor'), operation: Integer(saved.fetch('operation'))))
    raise 'Ruby changed the frozen capture binding' unless sealed == bundle
  else
    raise 'Old name rebound' unless client.lookup_table('captured_input').nil?
    definition = client.lookup_table('captured_renamed') or raise 'Missing renamed Table'
    raise 'Lost definition identity' unless definition.source.interpretation.revision == 2 && definition.source.schema.revision == 1
    page = client.page(1)
    raise 'Unexpected retained result' unless page.next.nil? && page.rows == 1 && page.manifest.resource == resource && page.manifest.source == connection.source
    raise 'Table cut interpreted as native revision' unless page.manifest.cut.is_a?(q::TableCut)
    raise 'Traversal changed' unless page.manifest.pages == 3 && page.manifest.scanned == 19
    rows = page.decode(native_host: host)
    raise 'Wrong retained COUNT' unless rows.length == 1 && rows[0][0].value.value == 19
    raise 'Missing separate cleanup' unless client.prepare_cleanup(1, bundle).is_a?(q::Prepared)
  end
end
puts "Ruby direct capture #{phase}: public API passed"
