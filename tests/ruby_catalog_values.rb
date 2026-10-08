# frozen_string_literal: true
require 'transit/station'
require 'timeout'
require_relative 'schema_values'
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
rejects(ArgumentError) { M::Connection.new(owner: Transit::ProcessRef.new(realm: 47, pid: 1), scope: scope) }
rejects(ArgumentError) { M::PolicyChange.new(expected_revision: -1, policy: nil) }
text = +'opaque recovery bytes'
prepared = M::Prepared.new(data: text); text.clear
check(prepared.data == 'opaque recovery bytes' && prepared.data.frozen?)
text = +'id'; columns = [M::Column.new(id: 1, name: text, type: L::Scalar.new(kind: :int128))]
schema = M::Schema.new(object: (1 << 64)-1, revision: 1, next_column: 2, columns: columns)
text.clear; columns.clear
check(schema.columns.first.name == 'id' && schema.columns.frozen? && schema.columns.first.name.frozen?)
bytes = +'saved'; saved = M::SavedIntent.new(definition: M::DEFINITION, bytes: bytes); bytes.clear
check(saved.bytes == 'saved' && saved.bytes.frozen?)
rejects(ArgumentError) { M::SavedIntent.new(definition: '0' * 64, bytes: 'saved') }
rejects(ArgumentError) { M::SavedIntent.new(definition: nil, bytes: 'saved') }
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

class Reply
  attr_accessor :response, :entered, :release
  attr_reader :closed, :action
  def catalog(action)
    @action = action
    if entered
      entered << true
      release.pop
    end
    raise response if response.is_a?(Exception)
    response
  end
  def evidence = nil
  def close = @closed = true
end
def owner(reply)
  client = M::Client.allocate
  client.instance_variable_set(:@worker, I::Worker.new { reply })
  client
end
reply = Reply.new; client = owner(reply)
client.instance_variable_set(:@connection, M::Connection.new(owner: Transit::ProcessRef.new(realm: 46, pid: 3), scope: scope))
client.instance_variable_set(:@principal, 17)
reference = M::Reference.new(definition: M::DEFINITION, digest: 'x' * 32)
begin
  [NoMemoryError.new('injected result allocation'), nil, {}, {'receipt'=>{'position'=>0}}, {'receipt'=>{'position'=>'1'}}, {'receipt'=>{'position'=>1.5}},
   {'receipt'=>{'position'=>1},'extra'=>true}, {'receipt'=>{'position'=>1,'extra'=>true}}].each do |value|
    reply.response = value
    error = rejects(M::Uncertain) { client.submit(prepared) }
    check(error.prepared.equal?(prepared))
  end
  reply.response = {'receipt'=>{'position'=>1}}
  check(client.submit(prepared) == 1)
  reply.response = Transit::AccessDenied.new('Denied', status: 4, code: 'AccessDenied')
  check(rejects(Transit::AccessDenied) { client.submit(prepared) }.equal?(reply.response))
  outcome = {'kind'=>'insert','operation'=>((1 << 64)-1).to_s,'object'=>((1 << 64)-1).to_s,'actual_object'=>((1 << 64)-1).to_s,
    'phase'=>'applied','terminal'=>true,'counts'=>{'matched'=>'1','changed'=>'1'},'admitted_input'=>7,'completed_input'=>8,
    'diagnostic'=>JSON.parse(File.read('../diagnostic.json'))}
  reply.response = {'state'=>{'outcome'=>clone_json(outcome),'upload'=>nil}}
  retained = client.status(reference)
  check(retained.outcome.object == (1 << 64)-1 && retained.outcome.counts == M::Counts.new(matched: 1, changed: 1))
  reply.response['state']['outcome']['diagnostic']['message'].clear
  check(!retained.outcome.diagnostic['message'].empty?)
  [{ 'counts'=>nil }, { 'terminal'=>false }, { 'phase'=>'unknown' }, { 'operation'=>'01' }, {'object'=>(1 << 64)-1}, {'diagnostic'=>nil}].each do |defect|
    reply.response = {'state'=>{'outcome'=>outcome.merge(defect),'upload'=>nil}}
    rejects(Transit::IncompatibleNative) { client.status(reference) }
  end
  metadata = {'scope'=>scope.wire,'object'=>((1 << 64)-1).to_s,'revision'=>((1 << 64)-1).to_s,'name'=>'items',
    'schema_fingerprint'=>'ab' * 32,'principal'=>17,'operation'=>((1 << 64)-1).to_s,'admitted_input'=>2,'commitment'=>{'format'=>0x54434d01,'length'=>200,'digest'=>[1]*32}}
  head = {'revision'=>'1','rows'=>'0','pending'=>'0'}
  entry = {'metadata'=>metadata,'head'=>head}
  token = {'definition'=>M::DEFINITION,'scope'=>scope.wire,'resource_revision'=>3,'after_object'=>((1 << 64)-1).to_s}
  page = {'resource_revision'=>3,'entries'=>[entry] + [nil] * 7,'next'=>token}
  reply.response = {'page'=>clone_json(page)}
  retained = client.list
  check(retained.entries.first.metadata.object == (1 << 64)-1 && retained.entries.first.metadata.revision == (1 << 64)-1)
  reply.response['page']['entries'][0]['metadata']['name'].clear
  check(retained.entries.first.metadata.name == 'items' && retained.entries.frozen?)
  check(retained.entries.first.metadata.commitment == M::MetadataCommitment.new(bytes: 200, digest: "\x01".b*32))
  entries = retained.entries.dup
  public_page = M::Page.new(resource_revision: 3, entries: entries, next: retained.next); entries.clear
  check(public_page.entries == retained.entries)
  definition = {'metadata'=>metadata,'head'=>head,'schema'=>schema.wire}
  reply.response = {'definition'=>clone_json(definition)}
  resolved = client.lookup('items')
  check(resolved.metadata == retained.entries.first.metadata && resolved.schema == schema)
  reply.response['definition']['schema']['columns'][0]['name'].clear
  check(resolved.schema.columns.first.name == 'id')
  reply.response = {'historical'=>{'metadata'=>clone_json(metadata),'schema'=>schema.wire}}
  historical = client.definition((1 << 64)-1, (1 << 64)-1)
  check(historical.metadata == resolved.metadata && historical.schema == schema && !historical.respond_to?(:head))
  rejects(Transit::IncompatibleNative) { client.definition(1, 1) }
  %i[hole order scope cut next_object missing_definition foreign_definition numeric_object unknown_head missing_commitment foreign_commitment long_commitment bad_digest].each do |defect|
    bad = clone_json(page)
    case defect
    when :hole then bad['entries'][1], bad['entries'][0] = bad['entries'][0], nil
    when :order then bad['entries'][1] = clone_json(entry)
    when :scope then bad['entries'][0]['metadata']['scope']['catalog'] = '1'
    when :cut then bad['next']['resource_revision'] += 1
    when :next_object then bad['next']['after_object'] = '1'
    when :missing_definition then bad['next'].delete('definition')
    when :foreign_definition then bad['next']['definition'] = '0' * 64
    when :numeric_object then bad['entries'][0]['metadata']['object'] = (1 << 64)-1
    when :unknown_head then bad['entries'][0]['head']['other'] = true
    when :missing_commitment then bad['entries'][0]['metadata'].delete('commitment')
    when :foreign_commitment then bad['entries'][0]['metadata']['commitment']['format'] = 0
    when :long_commitment then bad['entries'][0]['metadata']['commitment']['length'] = 437
    when :bad_digest then bad['entries'][0]['metadata']['commitment']['digest'][0] = 256
    end
    reply.response = {'page'=>bad}
    rejects(Transit::IncompatibleNative) { client.list }
  end
  reply.response = {'page'=>clone_json(page)}
  rejects(Transit::IncompatibleNative) { client.list(retained.next) }
  reply.response = {'page'=>{'resource_revision'=>4,'entries'=>[nil]*8,'next'=>nil}}
  rejects(Transit::IncompatibleNative) { client.list(retained.next) }
  reply.response['page']['resource_revision'] = 3
  check(client.list(retained.next).entries.empty?)
  reply.response = {'definition'=>nil}; check(client.lookup('absent').nil?)
  reply.response = {'historical'=>nil}; check(client.definition(1,1).nil?)
  reply.response = {'prepared'=>'signed'}
  check(client.prepare_control(reference, :collect_upload).data == 'signed')
  check(reply.action['prepare_control']['control'] == 'collect_upload')
  summary = {'reference'=>reference.wire,'scope'=>scope.wire,'owner'=>3,'principal'=>17,'operation'=>'10','namespace'=>'100','object'=>'1','kind'=>'insert'}
  compiled_reply = {'intent'=>summary,'saved'=>{'definition'=>M::DEFINITION,'bytes'=>'7361766564'}}
  operation = M::Mutate.new(basis: M::Basis.new(object: 1, revision: 1, schema_fingerprint: 'a' * 32),
    mutation: M::Insert.new(rows: [[M::Assignment.new(column: 1, value: atom(:binary, 'x' * 300000))]]))
  identity = M::Identity.new(operation: 10, namespace: 100)
  reply.response = {'compiled'=>clone_json(compiled_reply)}
  compiled = client.prepare('items', identity, operation)
  check(compiled.intent.identity == identity && JSON.generate(reply.action).bytesize > I::LIMITS.fetch('host_line_bytes'))
  {'owner'=>4,'principal'=>18,'operation'=>'11','namespace'=>'101','object'=>'2','kind'=>'update'}.each do |field, value|
    bad = clone_json(compiled_reply); bad['intent'][field] = value
    reply.response = {'compiled'=>bad}
    rejects(Transit::IncompatibleNative) { client.prepare('items', identity, operation) }
  end
  reply.response = {'loaded'=>summary}
  check(client.load(compiled.saved) == compiled.intent)
  check(reply.action == {'load'=>compiled.saved.wire})
ensure
  client.close
end
check(reply.closed)
rejects(Transit::Closed) { client.capabilities }
# A real owned child exercises generated response validation and transport loss.
require 'tmpdir'
Dir.mktmpdir('transit-catalog-replies-') do |directory|
  schemas = I::SCHEMAS.merge(JSON.parse(File.binread(File.join(Gem.loaded_specs.fetch('transit-station').full_gem_path,
    'lib/transit/station/schemas.json'))))
  # Catalog-only framing accepts bounded large requests and fragmented replies.
  host = File.join(directory, 'large-host')
  response = JSON.generate({'status'=>0,'value'=>{'compiled'=>compiled_reply.merge('saved'=>{'definition'=>M::DEFINITION,'bytes'=>'ab' * 300000})}}) + "\n"
  File.binwrite(File.join(directory, 'large-reply'), response)
  program = "#!/usr/bin/env ruby\nrequire 'json'\n$stdout.sync = true\nrequest = JSON.parse($stdin.gets)\nexit 3 unless request.fetch('catalog').fetch('load').fetch('bytes').bytesize == 600000\nFile.open(#{File.join(directory, 'large-reply').inspect}, 'rb') { |f| while part = f.read(97); $stdout.write(part); end }\n$stdin.each_line {}\n"
  File.write(host, program); File.chmod(0o700, host)
  action = {'catalog'=>{'load'=>{'definition'=>M::DEFINITION,'bytes'=>'ab' * 300000}}}
  port = I::Port.new(host, {}, schemas, 'HostRequest', line_bound: M::LIMITS.fetch('catalog_line_bytes'))
  begin
    result = port.request(action, phase: :catalog, response: 'CatalogResult')
    check(result['compiled']['saved']['bytes'].bytesize == 600000)
  ensure
    port.close
  end
  port = I::Port.new(host, {}, schemas, 'HostRequest')
  begin
    rejects(ArgumentError) { port.request(action, phase: :catalog, response: 'CatalogResult') }
  ensure
    port.close
  end
  [nil, {'status'=>0,'value'=>{'receipt'=>{'position'=>'1'}}},
   {'status'=>0,'value'=>{'receipt'=>{'position'=>1},'extra'=>true}}].each_with_index do |response, index|
    host = File.join(directory, "host-#{index}")
    program = "#!/usr/bin/env ruby\nrequire 'json'\n$stdout.sync = true\n$stdin.gets\n"
    program += response.nil? ? "exit 0\n" : "puts #{JSON.generate(response).inspect}\n$stdin.each_line {}\n"
    File.write(host, program); File.chmod(0o700, host)
    bridge = Transit::Station.const_get(:Bridge).allocate
    bridge.instance_variable_set(:@port, I::Port.new(host, {}, schemas, 'HostRequest'))
    client = owner(bridge)
    begin
      error = rejects(M::Uncertain) { client.submit(prepared) }
      raise 'Port failure changed recovery value' unless error.prepared.equal?(prepared)
    ensure
      client.close
    end
  end
end

# A cancelled waiting thread must not release the worker's active operation.
reply = Reply.new; reply.entered = Queue.new; reply.release = Queue.new
reply.response = {'receipt'=>{'position'=>2}}; client = owner(reply)
pending = Thread.new { client.submit(prepared) }
begin
  Timeout.timeout(5) { reply.entered.pop }
  pending.kill; pending.join
  rejects(Transit::Busy) { client.capabilities }
  closing = Thread.new { client.close }
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
  Thread.pass until closing.status == 'sleep' || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
  raise 'Close released active work' unless closing.alive? && !reply.closed
  reply.release << true
  Timeout.timeout(5) { closing.value }
  raise 'Close did not join cleanup' unless reply.closed
ensure
  reply.release << true
  pending.kill; pending.join
  client.close
end
puts 'Ruby general Tables: owned nested types, exact widths/budgets, strict metadata, catalog-only large frames, uncertain receipts and joined cancellation passed.'
