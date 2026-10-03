# frozen_string_literal: true
require 'json'
require 'transit/station'
$stdout.sync = true
M = Transit::Station::Catalog
cfg = JSON.parse(File.binread(ARGV.fetch(0)))
raise 'Catalog caller did not load installed gem' unless Gem.loaded_specs.fetch('transit-station').full_gem_path.start_with?(ENV.fetch('GEM_HOME'))

def scope(v)
  M::Scope.new(resource: Transit::ResourceRef.new(realm: v.fetch('realm'), resource: v.fetch('resource')),
    catalog: Integer(v.fetch('catalog'), 10))
end
def scope_json(v) = { realm: v.resource.realm, resource: v.resource.resource, catalog: v.catalog.to_s }
def configuration(v)
  s = scope(v.fetch('scope'))
  M::Configuration.new(scope: s, owner: Transit::ProcessRef.new(realm: s.resource.realm, pid: v.fetch('owner')),
    administrator: v.fetch('administrator'))
end
def configuration_json(v) = { scope: scope_json(v.scope), owner: v.owner.pid, administrator: v.administrator }
def policy(v)
  M::Policy.new(scope: scope(v.fetch('scope')), principal: v.fetch('principal'), revision: Integer(v.fetch('revision'), 10),
    can_inspect: v.fetch('inspect'), can_create: v.fetch('create'))
end
def policy_json(v) = { scope: scope_json(v.scope), principal: v.principal, revision: v.revision.to_s, inspect: v.can_inspect, create: v.can_create }
def request(v)
  schema = v.fetch('schema')
  M::CreateTable.new(scope: scope(v.fetch('scope')), operation: Integer(v.fetch('operation'), 10), object: Integer(v.fetch('object'), 10),
    table: v.fetch('table'), name: v.fetch('name'), schema: M::Schema.new(names: schema.fetch('names'), value_type: schema.fetch('value_type').to_sym))
end
def request_json(v)
  { scope: scope_json(v.scope), operation: v.operation.to_s, object: v.object.to_s, table: v.table, name: v.name,
    schema: { names: v.schema.names, value_type: v.schema.value_type } }
end
def prepared(v) = M::Prepared.new(data: v)
def cursor(v)
  v && M::Cursor.new(definition: v.fetch('definition'), scope: scope(v.fetch('scope')), resource_revision: v.fetch('resource_revision'), after: v.fetch('after'))
end
def cursor_json(v) = v && { definition: v.definition, scope: scope_json(v.scope), resource_revision: v.resource_revision, after: v.after }
def definition_json(v)
  v && { scope: scope_json(v.scope), object: v.object.to_s, revision: v.revision.to_s, name: v.name,
    source: { table: { id: v.source.table, schema: { names: v.source.schema.names, value_type: v.source.schema.value_type } } },
    principal: v.principal, operation: v.operation.to_s, input: v.input }
end
def call(client, action)
  name, v = action.first
  case name
  when 'capabilities'
    r = client.capabilities
    { capabilities: { version: r.version, definition: r.definition, initialize: r.initialize_catalog,
      create_table: r.create_table, conditional_policy: r.conditional_policy, current_metadata: r.current_metadata,
      max_saved_bytes: r.max_saved_bytes, table_columns: r.table_columns } }
  when 'describe'
    r = client.describe
    { description: { configuration: configuration_json(r.configuration), policy: policy_json(r.policy), resource_revision: r.resource_revision } }
  when 'lookup' then { definition: definition_json(client.lookup(v)) }
  when 'definition' then { definition: definition_json(client.definition(Integer(v.fetch('object'), 10), Integer(v.fetch('revision'), 10))) }
  when 'list'
    r = client.list(cursor(v))
    { page: { resource_revision: r.resource_revision, entries: r.entries.map { |entry| definition_json(entry) } + [nil] * (8-r.entries.length), next: cursor_json(r.next) } }
  when 'compile'
    r = client.compile_sql(v.fetch('sql'), Integer(v.fetch('operation'), 10), Integer(v.fetch('object'), 10), v.fetch('table'))
    { compiled: { request: request_json(r.request), canonical: r.canonical.unpack1('H*') } }
  when 'prepare_initialize' then { prepared: client.prepare_initialize(configuration(v)).data }
  when 'prepare_create' then { prepared: client.prepare_create(request(v)).data }
  when 'prepare_policy'
    { prepared: client.prepare_policy(M::PolicyChange.new(expected_revision: Integer(v.fetch('expected_revision'), 10), policy: policy(v.fetch('policy')))).data }
  when 'submit' then { receipt: { position: client.submit(prepared(v)) } }
  when 'observe' then { observation: client.observe(prepared(v.fetch('prepared')), v.fetch('input')) }
  when 'input_disposition'
    r = client.input_disposition(prepared(v.fetch('prepared')), v.fetch('input'))
    { disposition: r && { scope: scope_json(r.scope), origin: r.origin, principal: r.principal, input: r.input,
      payload: r.payload.unpack1('H*'), outcome: r.outcome } }
  when 'status'
    r = client.status(request(v))
    { status: r && { request: request_json(r.request), principal: r.principal, input: r.input, outcome: r.outcome } }
  else raise 'Unsupported catalog test action'
  end
end
c = cfg.fetch('connection'); s = scope(c.fetch('scope'))
connection = M::Connection.new(owner: Transit::ProcessRef.new(realm: s.resource.realm, pid: c.fetch('owner')), scope: s)
config = Transit::ClientConfig.new(url: cfg.fetch('url'), profile: :native_v1, timeout_ms: 10000)
credential = Transit::Credential.new(realm: s.resource.realm, principal: c.fetch('principal'), seed_file: cfg.fetch('seed_file'))
M::Client.open(config, credential, connection) do |client|
  puts JSON.generate(ready: true)
  $stdin.each_line do |line|
    action = JSON.parse(line)
    break if action.key?('close')
    begin
      puts JSON.generate(status: 0, value: call(client, action))
    rescue Transit::Error => error
      if error.is_a?(M::Uncertain)
        raise 'Uncertainty lost the original command' unless error.prepared.data == action.fetch('submit')
      end
      puts JSON.generate(status: error.status, value: { err: error.code, diagnostic: error.diagnostic, diagnostic_invalid: error.diagnostic_invalid })
    end
  end
end
puts JSON.generate(closed: true)
