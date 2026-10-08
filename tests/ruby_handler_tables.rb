# frozen_string_literal: true
require 'transit/station'
S = Transit::Station
C = S::Catalog
L = S::Logical
MAX = (1 << 64) - 1
$rejections = 0
def check(value)
  raise 'Handler Table assertion failed' unless value
end
def rejects(*errors)
  errors = [ArgumentError, Transit::IncompatibleNative] if errors.empty?
  begin
    yield
  rescue *errors
    $rejections += 1
    return
  end
  raise 'Invalid handler Table input accepted'
end
def atom(kind, value) = L::Present.new(value: L::Atom.new(kind: kind, value: value))
def clone_json(value) = JSON.parse(JSON.generate(value))
resource = Transit::ResourceRef.new(realm: 1, resource: 7)
schema = S::TableSchema.new(object: MAX, revision: 1, next_column: 5, columns: [
  C::Column.new(id: 1, name: 'id', type: L::Scalar.new(kind: :int64), nullable: false),
  C::Column.new(id: 2, name: 'name', type: L::Scalar.new(kind: :utf8)),
  C::Column.new(id: 3, name: 'amount', type: L::Decimal.new(precision: 18, scale: 2)),
  C::Column.new(id: 4, name: 'tags', type: L::List.new(element: L::Element.new(type: L::Scalar.new(kind: :binary), nullable: true)))
], primary_key: [1])
bytes = "\x00\xff".b
mutation = C::Insert.new(rows: [[C::Assignment.new(column: 1, value: atom(:signed, 7)),
  C::Assignment.new(column: 2, value: L::Null.new), C::Assignment.new(column: 3, value: atom(:decimal, 12345)),
  C::Assignment.new(column: 4, value: L::Present.new(value: L::Sequence.new(kind: :list, cells: [L::Null.new, atom(:binary, bytes)]))) ]])
intent = S::TableMutation.prepare(resource: resource, principal: 0, operation: MAX, schema: schema, mutation: mutation)
saved = intent.save
bytes.replace('changed')
check(S::TableMutation.load(saved).save == saved && intent.operation == MAX && intent.schema == schema)
check(intent.save.frozen?)
[
  ->(v) { v.fetch('schema').delete('definition') },
  ->(v) { v.fetch('schema')['definition'] = 'old' },
  ->(v) { v.delete('realm') },
  ->(v) { v['operation'] = 1 },
  ->(v) { v['operation'] = '0' },
  ->(v) { v['operation'] = '01' },
  ->(v) { v['operation'] = (1 << 64).to_s },
  ->(v) { v['table_write'] = {} },
  ->(v) { v.fetch('mutation').fetch('action').fetch('insert')[0][0].fetch('value')['extra'] = {} }
].each do |change|
  value = JSON.parse(saved); change.call(value)
  rejects { S::TableMutation.load(JSON.generate(value)) }
end
rejects { S::TableMutation.load(' ' + saved) }
rejects(JSON::NestingError) { S::TableMutation.load('[' * 2048 + ']' * 2048) }
rejects { S::TableMutation.prepare(resource: resource, principal: true, operation: 1, schema: schema, mutation: C::Delete.new) }
rejects { S::TableMutation.prepare(resource: resource, principal: 0, operation: 0, schema: schema, mutation: C::Delete.new) }
wide = S::TableSchema.new(object: 9, revision: 1, next_column: 129,
  columns: 128.times.map { |i| C::Column.new(id: i+1, name: "c#{i}", type: L::Scalar.new(kind: :int64)) })
rows = 1024.times.map { |i| [C::Assignment.new(column: 1, value: atom(:signed, i))] }
check(S::TableMutation.prepare(resource: resource, principal: 0, operation: 9, schema: wide, mutation: C::Insert.new(rows: rows)).schema.columns.length == 128)
rejects { C::Insert.new(rows: rows + [rows[0]]) }
rejects { S::TableMutation.prepare(resource: resource, principal: 0, operation: 9, schema: wide,
  mutation: C::Insert.new(rows: [[C::Assignment.new(column: 1, value: atom(:utf8, 'x' * C::LIMITS.fetch('handler_action_bytes')))]])) }
identity_bytes = (0...20).to_a.pack('C*')
identity = S::RowIdentity.new(bytes: identity_bytes)
identity_bytes.replace('changed')
check(identity.bytes == (0...20).to_a.pack('C*'))
rejects { S::RowIdentity.new(bytes: 'x' * 19) }
reference = { 'definition' => C::DEFINITION, 'realm' => 1, 'resource' => 7, 'object' => MAX.to_s,
  'principal' => 0, 'operation' => MAX.to_s, 'digest' => '11' * 32 }
ref = S::TableMutationReference.load(JSON.generate(reference))
[Transit::ResourceRef.new(realm: 2, resource: 7), Transit::ResourceRef.new(realm: 1, resource: 8)].each do |foreign|
  turn = Struct.new(:resource).new(foreign)
  rejects(Transit::HandlerError) { intent.step(turn) }
  rejects(Transit::HandlerError) { ref.status(turn) }
end
class Native
  attr_accessor :response
  attr_reader :calls
  def initialize = @calls = []
  def apply(scope, action)
    check(scope == 1)
    @calls << clone_json(action)
    clone_json(response)
  end
end
native = Native.new
stop = Object.new
def stop.stopped? = false
make_turn = -> { S::Turn.new(native, { 'scope' => 1, 'resource' => 7, 'resource_revision' => 2 }, Transit::ProcessRef.new(realm: 1, pid: 3), stop) }
turn = make_turn.call
metadata = { 'schema' => schema.wire, 'basis' => { 'resource' => 7, 'revision' => 2, 'object' => MAX.to_s, 'head' => '22' * 32 } }
native.response = { 'table' => { 'schema' => metadata } }
table = turn.table(MAX)
check(table.schema == schema && table.basis.resource == resource)
row = { 'identity' => identity.bytes.unpack1('H*'), 'cells' => [L.cell_wire(atom(:signed, 7)), L.cell_wire(L::Null.new), L.cell_wire(atom(:decimal, 12345)), L.cell_wire(L::Present.new(value: L::Sequence.new(kind: :list, cells: [L::Null.new])))] }
native.response = { 'table' => { 'row' => { 'definition' => metadata, 'row' => row } } }
found = table.get_key([atom(:signed, 7)])
check(found.identity == identity && found.cells[2] == atom(:decimal, 12345) && table.get(identity) == found)
native.response = { 'table' => { 'page' => { 'definition' => metadata, 'rows' => [row], 'next' => 'opaque' } } }
check(table.page(limit: 1).rows == [found] && table.page(limit: 1).cursor == 'opaque')
rejects { table.page(limit: 9) }
native.response.fetch('table').fetch('page').fetch('definition').fetch('basis')['revision'] = 3
rejects(Transit::IncompatibleNative) { table.page }
# A caught malformed read still poisons the real Ruby scope.
rejects(Transit::IncompatibleNative) { turn.table(MAX) }
turn = make_turn.call
metadata.fetch('basis')['revision'] = 2
native.response = { 'table' => { 'schema' => metadata } }
retained = turn.open_version(S::ReadVersion.new(pid: 3, input: 1, index: 0)).table(MAX)
rejects(Transit::HandlerError) { retained.prepare(principal: 0, operation: 1, mutation: C::Delete.new) }
status = { 'reference' => reference, 'state' => 'building', 'route' => 'statement', 'admitted_input' => 1,
  'completed_input' => nil, 'counts' => nil, 'rejection' => 'none', 'witness' => nil }
native.response = { 'table' => { 'mutation' => status } }
check(intent.step(turn).state == :building && ref.status(turn).counts.nil?)
status.merge!('state' => 'applied', 'completed_input' => 2, 'counts' => { 'matched' => '1', 'changed' => '1' })
check(intent.step(turn).counts.changed == 1 && ref.cancel(turn).state == :applied)
status['counts'] = nil
rejects(Transit::IncompatibleNative) { intent.step(turn) }
status.merge!('state' => 'building', 'completed_input' => nil, 'reference' => reference.merge('operation' => '2'))
rejects(Transit::IncompatibleNative) { intent.step(turn) }
status['reference'] = reference.merge('digest' => '22' * 32)
rejects(Transit::IncompatibleNative) { ref.status(turn) }
plan = S::QueryPlan.new(S::Unified::Plan.new(projection: [3, 0, 2], output_names: %w[tags identity amount], limit: MAX))
wire = plan.wire; wire.fetch('projection')[0] = 1
check(plan.wire.fetch('projection') == [3, 0, 2] && plan.wire.fetch('limit') == MAX.to_s)
check(S::QueryPlan.new(S::Unified::Plan.new(projection: (0...128).to_a)).wire.fetch('projection').length == 128)
rejects { S::Unified::Plan.new(projection: [128]) }
puts "Ruby handler Tables: owned values, scoped reads, saved intents and #{$rejections} adversarial rejections passed"
