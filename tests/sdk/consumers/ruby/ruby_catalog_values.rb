# frozen_string_literal: true
require 'transit/station'
require 'timeout'
require_relative 'ruby_schema_values'
M = Transit::Station::Catalog
L = Transit::Station::Logical
I = Transit.const_get(:Internal)
def rejects(*kinds)
  begin
    yield
  rescue *kinds => error
    return error
  end
  raise "Expected #{kinds}"
end
def check(value)
  raise 'Ruby catalog value assertion failed' unless value
end
def atom(kind, value, **other) = L::Present.new(value: L::Atom.new(kind: kind, value: value, **other))
def clone_json(value) = JSON.parse(JSON.generate(value))
scope = M::Scope.new(resource: Transit::ResourceRef.new(realm: 46, resource: 7), catalog: (1 << 64)-1)
rejects(ArgumentError) { M::Scope.new(resource: scope.resource, catalog: true) }
rejects(ArgumentError) { M::Scope.new(resource: scope.resource, catalog: 1 << 64) }
rejects(ArgumentError) { M::Connection.new(scope: scope, audience: 1, branch: 0) }
authority_values = {database_domain: 10, schema_domain: 11, table_domain: 12, database: 20, initial_schema: 1, initial_schema_authority: 21}
authority = M::AuthorityProfile.new(**authority_values)
rejects(ArgumentError) { M::AuthorityProfile.new(**authority_values.merge(table_domain: 10)) }
rejects(ArgumentError) { M::AuthorityProfile.new(**authority_values.merge(initial_schema_authority: 20)) }
context = 'a' * 32
subject = M::Subject.new(principal: 17, login_role: 17, role: 17, credential_epoch: 1, audience: 3, context: context)
context.clear
check(subject.context == 'a' * 32 && subject.context.frozen?)
rejects(ArgumentError) { M::Subject.new(**subject.to_h.merge(credential_epoch: 0)) }
text = +'id'; columns = [M::Column.new(id: 1, name: text, type: L::Scalar.new(kind: :int128))]
schema = M::Schema.new(object: (1 << 64)-1, revision: 1, next_column: 2, columns: columns)
text.clear; columns.clear
check(schema.columns.first.name == 'id' && schema.columns.frozen? && schema.columns.first.name.frozen?)
physical_wire = {'definition'=>M::DEFINITION, 'object'=>'7', 'revision'=>'2', 'next_column'=>'2',
  'columns'=>[{'id'=>'1', 'name'=>'text', 'type'=>{'utf8'=>{}}, 'nullable'=>true, 'default'=>nil,
    'max_characters'=>nil, 'encoding'=>'ebcdic', 'collation'=>'ebcdic_cp037'}], 'primary_key'=>[]}
physical = M.const_get(:Values).schema(physical_wire)
check(physical.columns.first.encoding == :ebcdic && physical.columns.first.collation == :ebcdic_cp037)
check(physical.wire == physical_wire)
check(M::SetPhysical.new(column: 1, encoding: :fsst, collation: :ascii_ci).wire ==
  {'physical'=>{'column'=>'1', 'encoding'=>'fsst', 'collation'=>'ascii_ci'}})
added = M::AddColumn.new(name: 'text', type: L::Scalar.new(kind: :utf8), encoding: :ebcdic, collation: :ebcdic_cp037).wire.fetch('add')
check(added['encoding'] == 'ebcdic' && added['collation'] == 'ebcdic_cp037')
%w[encoding collation].each do |field|
  bad = clone_json(physical_wire); bad['columns'][0].delete(field)
  rejects(Transit::IncompatibleNative) { M.const_get(:Values).schema(bad) }
  bad['columns'][0][field] = 'invented'
  rejects(Transit::IncompatibleNative) { M.const_get(:Values).schema(bad) }
end
raw = +'\x00\xff'; value = atom(:binary, raw); raw.clear
check(!value.value.value.empty? && value.value.value.frozen?)
values = [atom(:signed, -(1 << 127)), atom(:unsigned, (1 << 128)-1), atom(:decimal, 123456789012345678901234567890),
  atom(:date_days, -100), atom(:time_nanos, 123), atom(:timestamp_micros, -1000), atom(:boolean, false), atom(:utf8, '東京'),
  atom(:binary, [0,128,255].pack('C*')), atom(:uuid, 'x' * 16), atom(:float, -0.0, width: 32), atom(:float, 1.5, width: 64),
  atom(:interval, L::Interval.new(months: -1, days: 2, nanos: -3000)), L::Present.new(value: L::Json.new(json: '{"n":123}')),
  L::Missing.new, L::Null.new, L::SourceTypeError.new(actual: :map)]
values += %i[unknown null_value text character].map { |kind| L::SourceTypeError.new(actual: kind) }
values.each { |v| check(L.cell_from_wire(L.cell_wire(v)) == v) }
check(L.cell_wire(values[10])['value']['atom']['float_bits'] == '00000080')
check(1.0 / L.cell_from_wire(L.cell_wire(values[10])).value.value == -Float::INFINITY)
rejects(ArgumentError) { L.cell_wire(atom(:float, 1e100, width: 32)) }
rejects(ArgumentError) { L.cell_wire(atom(:signed, 1 << 127)) }
rejects(Transit::IncompatibleNative) { L.cell_from_wire({'value'=>{'atom'=>{'signed'=>'01'}}}) }
rejects(Transit::IncompatibleNative) { L.atom_from_wire({'uuid'=>'00'}) }
conflict = L::Conflict.new(alternatives: [L::Alternative.new(counter: 1, replica: 1, value: atom(:boolean, true)), L::Alternative.new(counter: 1, replica: 2, value: L::Null.new)])
deep = conflict
15.times { deep = L::Present.new(value: L::Sequence.new(kind: :list, cells: [deep])) }
check(L.cell_from_wire(L.cell_wire(deep)) == deep)
rejects(ArgumentError) { L.cell_wire(L::Present.new(value: L::Sequence.new(kind: :list, cells: [deep]))) }
rejects(ArgumentError) { L::Conflict.new(alternatives: conflict.alternatives.reverse) }
rejects(ArgumentError) { L::Alternative.new(counter: 0, replica: 1, value: L::Null.new) }
pair = L::MapEntry.new(key: L::Atom.new(kind: :signed, value: 1), value: L::Null.new)
map = L::Present.new(value: L::MapValue.new(entries: [pair] * 32767))
check(L.cell_from_wire(L.cell_wire(map)) == map)
rejects(ArgumentError) { L::MapValue.new(entries: [pair] * 32768) }
large = L::Present.new(value: L::Sequence.new(kind: :list, cells: [atom(:utf8, 'x' * 600000)] * 2))
rejects(ArgumentError) { L.cell_wire(large) }
large_cell = atom(:binary, 'x' * 1024 * 1024)
large_column = M::Column.new(id: 1, name: 'data', type: L::Scalar.new(kind: :binary), default: large_cell)
large_insert = M::Insert.new(rows: [[M::Assignment.new(column: 1, value: large_cell)]] * 1024)
original_cell_wire = L.method(:cell_wire)
visits = 0
L.define_singleton_method(:cell_wire) do |value|
  visits += 1
  raise 'Converted complete oversized input' if visits >= 16
  original_cell_wire.call(value)
end
begin
  check(rejects(ArgumentError) { M::Schema.new(object: 1, revision: 1, next_column: 2, columns: [large_column] * 128) }.message == 'Table wire budget exceeded')
  visits = 0
  check(rejects(ArgumentError) { large_insert.wire }.message == 'Table wire budget exceeded')
  check(visits < 16)
ensure
  L.define_singleton_method(:cell_wire, &original_cell_wire)
end
rejects(ArgumentError) { L.cell_from_wire({'value'=>{'list'=>[{'value'=>{'atom'=>{'utf8'=>'x' * 600000}}}]*2}}) }
types = L::SCALARS.map { |kind| L::Scalar.new(kind: kind) } + [L::Decimal.new(precision: 38, scale: 2), L::Timestamp.new(zone: :utc)]
element = L::Element.new(type: L::Decimal.new(precision: 38, scale: 2), nullable: true)
types += [L::List.new(element: element), L::ArrayType.new(element: element, length: 4), L::Map.new(key: L::Scalar.new(kind: :utf8), value: element), L::Structure.new(fields: [L::Field.new(name: 'amount', type: element.type)]), L::Union.new(fields: [L::Field.new(name: 'text', type: L::Scalar.new(kind: :utf8))])]
types.each { |v| check(L.type_from_wire(L.type_wire(v)) == v) }
rejects(ArgumentError) { L.type_wire(L::Structure.new(fields: [L::Field.new(name: 'x' * 2100, type: types.first)] * 2)) }
rejects(ArgumentError) { L.type_wire(L::Structure.new(fields: [L::Field.new(name: 'n', type: types.first)] * 256)) }

connection = M::Connection.new(scope: scope, audience: 3)
v = M.const_get(:Values)
object = {'scope'=>scope.wire, 'branch'=>'1', 'object'=>((1<<64)-1).to_s}
interpretation = {'object'=>object, 'revision'=>'1', 'digest'=>'ab'*32}
stored = {'interpretation'=>interpretation, 'content'=>{'bytes'=>'300','sha256'=>'ab'*32}, 'schema_fingerprint'=>'cd'*32, 'retired'=>false}
basis_wire = {'definition'=>M::DEFINITION,'connection'=>connection.wire(17),'namespace'=>1,'name'=>'items','interpretation'=>stored}
basis = M::Basis.restore(JSON.generate(basis_wire))
check(basis.object == (1<<64)-1 && basis.name == 'items' && basis.connection == connection)
rejects(ArgumentError) { M::Basis.restore(JSON.generate(basis_wire)[0...-1] + ',"name":"other"}') }
rejects(FrozenError) { basis.instance_variable_set(:@data, 'changed') }
check(!basis.inspect.include?('items'))
bound = {'definition'=>M::DEFINITION,'identity'=>{'scope'=>scope.wire,'principal'=>17,'operation'=>'10'}, 'target'=>object,
  'action'=>'insert','expected_definition'=>interpretation,'expected_data'=>nil,'intent'=>'aa'*32,'prerequisite'=>nil}
saved_wire = {'table'=>{'definition'=>M::DEFINITION,'namespace'=>1,'bytes'=>'opaque saved bytes'.unpack1('H*')}}
saved = M::SavedIntent.restore(JSON.generate(saved_wire))
summary = {'id'=>{'definition'=>M::DEFINITION,'digest'=>'11'*32},'namespace'=>1,'binding'=>{'table'=>bound}}
compiled_wire = {'summary'=>summary,'saved'=>saved_wire}
reference_wire = {'table'=>{'definition'=>M::DEFINITION,'connection'=>connection.wire(17),'namespace'=>1,'binding'=>bound,'content'=>{'bytes'=>'200','sha256'=>'22'*32}}}
reference = M::Reference.restore(JSON.generate(reference_wire))
[[M::SavedIntent,saved_wire],[M::Reference,reference_wire],[M::Basis,basis_wire]].each do |klass, raw|
  [nil, '0'*64].each do |definition|
    bad = clone_json(raw); target = bad['table'] || bad
    definition.nil? ? target.delete('definition') : target['definition'] = definition
    rejects(ArgumentError, Transit::IncompatibleNative) { klass.restore(JSON.generate(bad)) }
  end
end
class Reply
  attr_accessor :response, :entered, :release
  attr_reader :closed, :action
  def catalog(action)
    @action = action
    if entered then entered << true; release.pop; end
    raise response if response.is_a?(Exception)
    response
  end
  def evidence = nil
  def close = @closed = true
end
def owner(reply, connection)
  client = M::Client.allocate
  client.instance_variable_set(:@worker, I::Worker.new { reply })
  client.instance_variable_set(:@connection, connection)
  client.instance_variable_set(:@principal, 17)
  client
end
reply = Reply.new; client = owner(reply, connection)
begin
  reply.response = {'compiled'=>clone_json(compiled_wire)}
  operation = M::Mutate.new(basis: basis, mutation: M::Insert.new(rows: [[M::Assignment.new(column: 1, value: atom(:binary, 'x' * 300000))]]), ingestion: :bulk)
  compiled = client.prepare('items', M::Identity.new(operation: 10), operation)
  check(compiled.intent.identity.operation == 10 && compiled.saved == saved && JSON.generate(reply.action).bytesize > I::LIMITS.fetch('host_line_bytes'))
  reply.response = {'staged'=>clone_json(reference_wire)}
  check(client.stage(compiled.intent) == reference)
  reply.response = {'loaded'=>clone_json(summary)}
  check(client.load(saved) == compiled.intent)
  [nil, {}, {'staged'=>{}}, Transit::UnknownOutcome.new('lost', status: 6), NoMemoryError.new('injected')].each do |value|
    reply.response = value
    error = rejects(M::Uncertain) { client.stage(compiled.intent) }
    check(error.original.equal?(compiled.saved) && error.status == 6)
  end
  reply.response = Transit::AccessDenied.new('Denied', status: 4)
  check(rejects(Transit::AccessDenied) { client.execute(reference) }.equal?(reply.response))
  outcome = {'rows'=>{'committed'=>{'binding'=>bound, 'resulting'=>stored,
    'outcome'=>{'position'=>{'partition'=>'18446744073709551615','next_lsn'=>'18446744073709551615'},'matched'=>'9','affected'=>'9','live_rows'=>'9'}}}}
  reply.response = {'observation'=>clone_json(outcome)}
  observed = client.inspect(reference)
  check(observed.state == :committed && observed.commit.matched == 9 && observed.commit.position.next_lsn == (1<<64)-1)
  reply.response['observation']['rows']['committed']['binding']['identity']['operation'] = '11'
  rejects(Transit::IncompatibleNative) { client.inspect(reference) }
  check(rejects(M::Uncertain) { client.execute(reference) }.original.equal?(reference))
  bad = clone_json(outcome); bad['rows']['committed']['outcome']['affected'] = '10'
  reply.response = {'observation'=>bad}; rejects(Transit::IncompatibleNative) { client.inspect(reference) }
  description = {'configuration'=>{'scope'=>scope.wire,'branch'=>'1','partition'=>'18446744073709551615','audience'=>3,
    'authority'=>authority.wire,'database_name'=>'ledger','initial_schema_name'=>'public'},
    'subject'=>subject.to_h.transform_keys(&:to_s).merge('context'=>subject.context.bytes), 'policy_revision'=>2}
  reply.response = {'catalog'=>{'description'=>description}}
  current = client.describe
  check(current.subject == subject && current.configuration.authority == authority && current.policy_revision == 2)
  {'principal'=>18,'audience'=>4,'credential_epoch'=>0}.each do |field, value|
    bad = clone_json(description); bad['subject'][field] = value
    reply.response = {'catalog'=>{'description'=>bad}}
    rejects(Transit::IncompatibleNative) { client.describe }
  end
  position = {'partition'=>'18446744073709551615','next_lsn'=>'4'}
  entry = {'interpretation'=>interpretation,'namespace'=>1,'name'=>'items','position'=>position,'changed_lsn'=>'3'}
  token = {'definition'=>M::DEFINITION,'connection'=>connection.wire(17),'selection'=>{'tables'=>1},'position'=>position,'after'=>object['object']}
  page = {'position'=>position,'entries'=>[entry]+[nil]*7,'next'=>token,'consistency'=>'independent'}
  reply.response = {'catalog'=>{'tables'=>clone_json(page)}}
  retained = client.tables
  check(retained.entries.first.interpretation.object.object == (1<<64)-1 && retained.next.after == (1<<64)-1)
  reply.response['catalog']['tables']['entries'][0]['name'].clear
  check(retained.entries.first.name == 'items' && retained.entries.frozen?)
  %i[hole order scope namespace cut next_object missing_definition foreign_definition numeric_object].each do |defect|
    bad = clone_json(page)
    case defect
    when :hole then bad['entries'][1],bad['entries'][0] = bad['entries'][0],nil
    when :order then bad['entries'][1] = clone_json(entry)
    when :scope then bad['entries'][0]['interpretation']['object']['scope']['catalog'] = '1'
    when :namespace then bad['entries'][0]['namespace'] = 2
    when :cut then bad['next']['position'] = {'partition'=>'1','next_lsn'=>'5'}
    when :next_object then bad['next']['after'] = '1'
    when :missing_definition then bad['next'].delete('definition')
    when :foreign_definition then bad['next']['definition'] = '0'*64
    when :numeric_object then bad['entries'][0]['interpretation']['object']['object'] = (1<<64)-1
    end
    reply.response = {'catalog'=>{'tables'=>bad}}
    rejects(Transit::IncompatibleNative) { client.tables }
  end
  reply.response = {'catalog'=>{'tables'=>clone_json(page)}}
  rejects(Transit::IncompatibleNative) { client.tables(cursor: retained.next) }
  metadata = {'binding'=>basis_wire,'authorization'=>30,'position'=>position,'changed_lsn'=>'3','row_count'=>'9','schema'=>schema.wire}
  reply.response = {'metadata'=>clone_json(metadata)}
  found = client.lookup('items'); check(found.basis == basis && found.row_count == 9 && found.schema == schema)
  reply.response = {'metadata'=>nil}; check(client.lookup('absent').nil?)
  acquisition = client.prepare_snapshot(basis, found.position, (1<<64)-1)
  check(acquisition.owner.operation == (1<<64)-1)
  snapshot_wire = {'owner'=>acquisition.owner.wire,'content'=>{'bytes'=>'500','sha256'=>'44'*32}}
  reply.response = {'retention'=>{'acquired'=>clone_json(snapshot_wire)}}
  snapshot = client.acquire_snapshot(acquisition)
  check(snapshot.owner == acquisition.owner && snapshot.content.bytes == 500)
  reply.response = {'retention'=>{'released'=>clone_json(snapshot_wire)}}
  check(client.release_snapshot(snapshot) == snapshot)
  reply.response['retention']['released']['content']['sha256'] = '55'*32
  check(rejects(M::Uncertain) { client.release_snapshot(snapshot) }.original.equal?(snapshot))
  reply.response = {'retention'=>{'metadata'=>{'snapshot'=>snapshot_wire,'interpretation'=>stored,'accepted'=>position,
    'changed_lsn'=>'3','row_count'=>'9','schema'=>schema.wire,'authority'=>{'database'=>31,'schema'=>32,'table'=>33}}}}
  check(client.snapshot_metadata(snapshot).accepted == found.position)
ensure
  client.close
end
check(reply.closed)
rejects(Transit::Closed) { client.capabilities }

# The real port validates generated response shapes and treats loss after a
# mutating dispatch as uncertainty, including replies that claim success.
require 'tmpdir'
Dir.mktmpdir('transit-direct-catalog-replies-') do |directory|
  station_module = $LOADED_FEATURES.find { |file| file.end_with?('/transit/station.rb') }
  schemas = I::SCHEMAS.merge(JSON.parse(File.binread(File.join(File.dirname(station_module), 'station/schemas.json'))))
  host = File.join(directory, 'large-host')
  large = clone_json(compiled_wire); large['saved']['table']['bytes'] = 'ab' * 300000
  response = JSON.generate({'status'=>0,'value'=>{'compiled'=>large}}) + "\n"
  File.binwrite(File.join(directory, 'large-reply'), response)
  File.write(host, "#!/usr/bin/env ruby\nrequire 'json'\n$stdout.sync = true\nrequest = JSON.parse($stdin.gets)\nexit 3 unless request.fetch('catalog').fetch('load').fetch('table').fetch('bytes').bytesize == 600000\nFile.open(#{File.join(directory, 'large-reply').inspect}, 'rb') { |f| while part = f.read(97); $stdout.write(part); end }\n$stdin.each_line {}\n")
  File.chmod(0o700, host)
  action = {'catalog'=>{'load'=>large['saved']}}
  port = I::Port.new(host, {}, schemas, 'HostRequest', line_bound: M::LIMITS.fetch('catalog_line_bytes'))
  begin
    check(port.request(action, phase: :catalog, response: 'CatalogResult')['compiled']['saved']['table']['bytes'].bytesize == 600000)
  ensure
    port.close
  end
  [nil, {'status'=>0,'value'=>{'observation'=>{}}}].each_with_index do |response, index|
    host = File.join(directory, "host-#{index}")
    program = "#!/usr/bin/env ruby\nrequire 'json'\n$stdout.sync = true\n$stdin.gets\n"
    program += response.nil? ? "exit 0\n" : "puts #{JSON.generate(response).inspect}\n$stdin.each_line {}\n"
    File.write(host, program); File.chmod(0o700, host)
    bridge = Transit::Station.const_get(:Bridge).allocate
    bridge.instance_variable_set(:@port, I::Port.new(host, {}, schemas, 'HostRequest'))
    client = owner(bridge, connection)
    begin
      check(rejects(M::Uncertain) { client.execute(reference) }.original.equal?(reference))
    ensure
      client.close
    end
  end
end
reply = Reply.new; reply.entered = Queue.new; reply.release = Queue.new
reply.response = {'observation'=>clone_json(outcome)}; client = owner(reply, connection)
pending = Thread.new { client.execute(reference) }
begin
  Timeout.timeout(5) { reply.entered.pop }
  pending.kill; pending.join
  rejects(Transit::Busy) { client.capabilities }
  closing = Thread.new { client.close }
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
  Thread.pass until closing.status == 'sleep' || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
  check(closing.alive? && !reply.closed)
  reply.release << true
  Timeout.timeout(5) { closing.value }
  check(reply.closed)
ensure
  reply.release << true
  pending.kill; pending.join
  client.close
end
puts 'Ruby direct catalog: owned nested values, wide bindings, exact metadata and snapshots, uncertain replies, large framing and joined cancellation passed.'
