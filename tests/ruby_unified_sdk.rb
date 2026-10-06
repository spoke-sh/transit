# frozen_string_literal: true
require 'transit/station'
require 'json'
Q = Transit::Station::Unified
L = Transit::Station::Logical
C = Transit::Station::Catalog
def scalar(type, value)
  return Q::Scalar.new(kind: :float, value: value, width: 64) if type == :float64
  Q::Scalar.new(kind: { int64: :signed, uint64: :unsigned }.fetch(type, type), value: value)
end
def table_source(columns)
  metadata = C::Metadata.new(scope: C::Scope.new(resource: Transit::ResourceRef.new(realm: 1, resource: 7), catalog: 9),
    object: 9, revision: 1, name: 'items', schema_fingerprint: "\x01".b*32, principal: 17, operation: 1, admitted_input: 1,
    commitment: C::MetadataCommitment.new(bytes: 200, digest: "\x01".b*32))
  Q::TableSource.new(owner: Transit::ProcessRef.new(realm: 1, pid: 3), metadata: metadata,
    schema: C::Schema.new(object: 9, revision: 1, next_column: columns.length+1, columns: columns))
end
def check(value)
  raise 'Unified Ruby assertion failed' unless value
end
def inspected_predicate(value)
  case value
  when nil then { all: {} }
  when Q::InspectedState then { state: { column: value.column, value: value.state } }
  when Q::InspectedComparison then { compare: { column: value.column, op: value.comparison, type: L.type_wire(value.type) } }
  else { program: value.instructions.map { |v| v.is_a?(Q::InspectedAtom) ? { atom: inspected_predicate(v.predicate) } : { v => {} } } }
  end
end
def codecs(config)
  resource = Transit::ResourceRef.new(realm: 46, resource: 7)
  sources = [Q::KVSource.new(resource: resource, prefix: 'data/', key: Q::Decoder.new(type: :binary), value: Q::Decoder.new(type: :uint64)),
    table_source([C::Column.new(id: 1, name: 'id', type: L::Scalar.new(kind: :int64), nullable: false), C::Column.new(id: 2, name: 'label', type: L::Scalar.new(kind: :utf8))]),
    Q::DocumentSource.new(reference: Transit::Station::DocumentReference.new(resource: resource, document: (1 << 64)-1, epoch: 3, type_revision: 1, revision: 42),
      projections: [Q::Projection.new(column: Q::DecoderColumn.new(name: 'title', type: :utf8), path: ['title']),
        Q::Projection.new(column: Q::DecoderColumn.new(name: 'body', type: :utf8), path: ['body'], mode: :text)])]
  fixtures = JSON.parse(File.read(config.fetch('bundles')))
  sources.each_with_index do |source, index|
    scalar = index.zero? ? Q::Scalar.new(kind: :unsigned, value: (1 << 64)-1) : Q::Scalar.new(kind: :utf8, value: 'x'*512)
    bundle = Q::Bundle.prepare(source, Q::Plan.new(projection: [1, 0], predicate: Q::Compare.new(column: 1, comparison: :ne, value: scalar), limit: (1 << 64)-1),
      Q::Budgets.new(pages: 1000, segments: 500, result_bytes: 1048576))
    check(bundle.data.unpack1('H*') == fixtures[index].fetch('wire_hex'))
    check(bundle.data.frozen?)
    named = Q::Bundle.prepare(source, Q::Plan.new(projection: [1, 0], output_names: ['Result', nil], predicate: Q::Compare.new(column: 1, comparison: :ne, value: scalar), limit: (1 << 64)-1),
      Q::Budgets.new(pages: 1000, segments: 500, result_bytes: 1048576))
    check(named.data.unpack1('H*') == fixtures[index].fetch('named_wire_hex'))
    counted = Q::Bundle.prepare(source, Q::Plan.new(projection: [1], aggregate: :count_values, output_names: ['present']), Q::Budgets.new(pages: 1000, segments: 500, result_bytes: 1048576))
    check(counted.data.unpack1('H*') == fixtures[index].fetch('counted_wire_hex'))
  end
  begin
    Q::Bundle.prepare(Q::KVSource.new(resource: resource, prefix: '', key: Q::Decoder.new(type: :binary, version: 2), value: Q::Decoder.new(type: :utf8)),
      Q::Plan.new(projection: [0]), Q::Budgets.new(pages: 1, segments: 1, result_bytes: 1))
    raise 'Unsupported decoder accepted'
  rescue Transit::Error
    nil
  end
  scalar_values = [-(1 << 63), (1 << 64)-1, -0.0, true, 'café é 🙂', "\x00\xff\x80".b, 'x'*512]
  JSON.parse(File.read(config.fetch('boolean'))).each_with_index do |fixture, index|
    type = Q::DECODER_TYPES[fixture.fetch('type')-1]
    source = Q::KVSource.new(resource: resource, prefix: ''.b, key: Q::Decoder.new(type: type), value: Q::Decoder.new(type: :uint64))
    instructions = if index < 7
      [Q::PredicateAtom.new(predicate: Q::Compare.new(column: 0, comparison: :eq, value: scalar(type, scalar_values[index]))),
        :negate, Q::PredicateAtom.new(predicate: Q::IsState.new(column: 0, state: :null)), :disjunction]
    elsif fixture.fetch('name') == 'all-and-not-null'
      [Q::PredicateAtom.new, Q::PredicateAtom.new(predicate: Q::IsState.new(column: 0, state: :null)), :negate, :conjunction]
    else [Q::PredicateAtom.new] + [:negate]*63
    end
    program = Q::PredicateProgram.new(instructions: instructions)
    instructions.clear
    bundle = Q::Bundle.prepare(source, Q::Plan.new(projection: [0], predicate: program), Q::Budgets.new(pages: 1000, segments: 500, result_bytes: 1048576))
    raise 'Boolean bundle mismatch' unless bundle.data.unpack1('H*') == fixture.fetch('wire_hex')
  end
  source = Q::KVSource.new(resource: resource, prefix: ''.b, key: Q::Decoder.new(type: :int64), value: Q::Decoder.new(type: :uint64))
  [[], [:negate], [Q::PredicateAtom.new, Q::PredicateAtom.new], [Q::PredicateAtom.new]+[:negate]*64,
    [Q::PredicateAtom.new(predicate: Q::Compare.new(column: 0, comparison: :eq, value: Q::Scalar.new(kind: :utf8, value: 'wrong type')))]].each do |instructions|
    begin
      Q::Bundle.prepare(source, Q::Plan.new(projection: [0], predicate: Q::PredicateProgram.new(instructions: instructions)), Q::Budgets.new(pages: 1, segments: 1, result_bytes: 1024))
      raise 'invalid predicate program accepted'
    rescue ArgumentError, Transit::Error
    end
  end
  columns = %i[int64 uint64 float64 boolean utf8 binary].map { |type| Q::Column.new(name: type.to_s, type: L::Scalar.new(kind: type), nullable: true, optional: true) }
  rows = Q.decode_arrow(columns, File.binread(config.fetch('arrow')), 5)
  check(rows.length == 5 && rows.all? { |row| row.length == 6 })
  [L::Missing, L::Null, L::SourceTypeError, L::Present, L::Conflict].each_with_index { |state, index| check(rows[index].all? { |cell| cell.is_a?(state) }) }
  [-(1 << 63), (1 << 64)-1, -0.0, false, 'café é 東京🙂', "\0\xff\x80".b].each_with_index do |value, index|
    check(rows[3][index].value.value == value)
    alternatives = rows[4][index].alternatives
    check(alternatives.map { |v| [v.counter, v.replica, v.value.class] } == [[(1 << 64)-1, 1, L::Present], [(1 << 64)-1, 2, L::Null]])
    check(alternatives[0].value.value.value == value)
  end
  check([rows[3][2].value.value].pack('E').unpack1('H*') == '0000000000000080')
  check(Q.decode_arrow(columns, File.binread(config.fetch('empty')), 0) == [])
  begin
    Q.decode_arrow(columns, File.binread(config.fetch('malformed')), 5)
    raise 'Hidden Arrow value accepted'
  rescue Transit::Error
    nil
  end
  wide_source = table_source(128.times.map { |i| C::Column.new(id: i+1, name: "列 #{i}", type: L::Scalar.new(kind: :uint128)) })
  wide = Q::Bundle.prepare(wide_source, Q::Plan.new(projection: (0...128).to_a,
    predicate: Q::Compare.new(column: 127, comparison: :eq, value: Q::Scalar.new(kind: :unsigned, value: (1 << 128)-1))),
    Q::Budgets.new(pages: 1, segments: 1, result_bytes: 65536))
  check(wide.data.bytesize > 1000)
  datatype = L::List.new(element: L::Element.new(type: L::Scalar.new(kind: :uint128), nullable: true))
  nested = Q.decode_arrow([Q::Column.new(name: 'value', type: datatype)], File.binread(config.fetch('nested')), 1)
  check(nested == [[L::Present.new(value: L::Sequence.new(kind: :list,
    cells: [L::Present.new(value: L::Atom.new(kind: :unsigned, value: (1 << 128)-1)), L::Null.new]))]])
  puts 'Ruby installed unified codecs: three sources, nine Boolean bundles, six scalar types, 128 columns, nested uint128, five states and malformed rejection passed'
end
def serve(config)
  v = config.fetch('connection')
  resource = Transit::ResourceRef.new(realm: v.fetch('realm'), resource: v.fetch('resource'))
  connection = Q::Connection.new(source: Transit::ProcessRef.new(realm: v.fetch('realm'), pid: v.fetch('source')), resource: resource,
    requester: Transit::ProcessRef.new(realm: v.fetch('realm'), pid: v.fetch('requester')), requests: Transit::ResourceRef.new(realm: v.fetch('realm'), resource: v.fetch('requests')))
  cfg = Transit::ClientConfig.new(url: config.fetch('url'), profile: :native_v1, timeout_ms: 10000)
  credential = Transit::Credential.new(realm: v.fetch('realm'), principal: v.fetch('principal'), seed_file: config.fetch('seed_file'))
  source = case config.fetch('kind')
  when 'kv' then Q::KVSource.new(resource: resource, prefix: 'k', key: Q::Decoder.new(type: :binary), value: Q::Decoder.new(type: :utf8))
  when 'table'
    catalog_connection = C::Connection.new(owner: connection.source, scope: C::Scope.new(resource: resource, catalog: 1))
    definition = C::Client.open(cfg, credential, catalog_connection) { |client| client.lookup('items') }
    check(!definition.nil?)
    Q::TableSource.new(owner: connection.source, metadata: definition.metadata, schema: definition.schema)
  else Q::DocumentSource.new(reference: Transit::Station::DocumentReference.new(resource: resource, document: 17, epoch: 1, type_revision: 1, revision: 13), expand: ['items'], projections: [
    Q::Projection.new(column: Q::DecoderColumn.new(name: 'value', type: :utf8), relative: true),
    Q::Projection.new(column: Q::DecoderColumn.new(name: 'counter', type: :uint64), relative: true, mode: :element_counter),
    Q::Projection.new(column: Q::DecoderColumn.new(name: 'replica', type: :uint64), relative: true, mode: :element_replica),
    Q::Projection.new(column: Q::DecoderColumn.new(name: 'optional', type: :utf8), path: ['optional'])])
  end
  doc = config.fetch('kind') == 'document'
  column = doc ? 0 : 1
  predicate = Q::Compare.new(column: column, comparison: :ne, value: Q::Scalar.new(kind: :utf8, value: 'x'*512))
  if config.fetch('compound')
    ceiling = "東京🙂/#{'x'*(doc ? 64 : 128)}/#{doc ? '10' : '39'}"
    predicate = Q::PredicateProgram.new(instructions: [Q::PredicateAtom.new(predicate: predicate),
      Q::PredicateAtom.new(predicate: Q::Compare.new(column: column, comparison: :ge, value: Q::Scalar.new(kind: :utf8, value: ceiling))),
      Q::PredicateAtom.new(predicate: Q::IsState.new(column: column, state: :null)), :disjunction, :negate, :conjunction])
  end
  bundle = Q::Bundle.prepare(source, Q::Plan.new(projection: doc ? [0, 1, 2, 3] : [1], output_names: doc ? ['Result', nil, nil, nil] : ['Result'], predicate: predicate), Q::Budgets.new(pages: 1000, segments: 100, result_bytes: 1048576))
  check(bundle.data == File.binread(config.fetch('bundle')))
  Q::Client.open(cfg, credential, connection) do |client|
    description = client.describe(source)
    check(description.bundle_bytes == 25069 && description.batch_rows == 8)
    puts JSON.generate(ready: true)
    STDIN.each_line do |line|
      action = JSON.parse(line)
      break if action.key?('close')
      begin
        result = if action.key?('compile')
          request = action.fetch('compile'); scope = request.fetch('scope'); limits = scope.fetch('limits')
          parameters = request['parameters']&.map { |item| L.atom_from_wire(item) }
          value = client.compile_sql(source, scope.fetch('name'), request.fetch('sql'), Q::Budgets.new(
            pages: Integer(limits.fetch('pages')), segments: Integer(limits.fetch('segments')), result_bytes: Integer(limits.fetch('result_bytes'))), parameters: parameters)
          { compiled: { bundle: value.data.unpack1('H*') } }
        elsif action.key?('inspect')
          request = action.fetch('inspect')
          scope = request.fetch('scope')
          limits = scope.fetch('limits')
          value = client.inspect_sql(source, scope.fetch('name'), request.fetch('sql'), Q::Budgets.new(
            pages: Integer(limits.fetch('pages')), segments: Integer(limits.fetch('segments')), result_bytes: Integer(limits.fetch('result_bytes'))))
          check(value.resource == resource && value.source_kind.to_s == config.fetch('kind'))
          check(value.source_digest.frozen? && value.schema_digest.frozen? && value.details.frozen?)
          data = value.details
          details = case data
          when Q::SourceDescription then { description: { columns: data.columns.map(&:wire) } }
          when Q::TableListing then { tables: data.names }
          when Q::Explanation
            predicate = inspected_predicate(data.predicate)
            check(data.columns.frozen? && data.projection.frozen? && data.operators.frozen?)
            { explanation: { operators: data.operators, predicate: predicate, projection: data.projection, limit: data.limit&.to_s,
              aggregate: data.aggregate, columns: data.columns.map(&:wire), budgets: data.budgets.to_h.transform_values(&:to_s) } }
          else raise 'Unknown SQL inspection result'
          end
          { inspection: { version: 1, scope: 'configured_source', name: value.name, resource: resource.resource,
            source_kind: value.source_kind, contract: value.source_digest.bytes, schema: value.schema_digest.bytes,
            resource_revision: value.resource_revision, policy_revision: value.policy_revision.to_s, details: details } }
        elsif action.key?('next')
          value = action.fetch('next')
          prepared = client.prepare_next(Integer(value.fetch('namespace')), Q::Bundle.new(data: [value.fetch('bundle')].pack('H*')))
          { prepared: prepared&.data }
        elsif action.key?('submit')
          prepared = Q::Prepared.new(data: action.fetch('submit'))
          begin
            { receipt: { position: client.submit(prepared) } }
          rescue Q::Uncertain => error
            check(error.prepared.data == prepared.data)
            raise
          end
        elsif action.key?('observe')
          observed = client.observe(action.fetch('observe'))
          { observation: { observed.state => observed.reason.nil? ? {} : observed.reason.unpack1('H*') } }
        elsif action.key?('status')
          status = client.status(Integer(action.fetch('status')))
          { status: status.nil? ? nil : { phase: status.phase, correlation: status.correlation.to_s, diagnostic: status.diagnostic, failure: status.failure&.then { |f| {code: f.code, stage: f.stage, dimension: f.dimension, limit: f.limit.to_s, observed: f.observed.to_s} } } }
        elsif action.key?('page')
          value = action.fetch('page')
          page = client.page(Integer(value.fetch('namespace')), value['cursor'].nil? ? nil : Q::Cursor.new(data: value.fetch('cursor')))
          check(page.manifest.resource == resource && page.manifest.source_kind.to_s == config.fetch('kind'))
          check(page.decode.length == page.rows && page.ipc.frozen?)
          { page: { ordinal: page.ordinal.to_s, ipc: page.ipc.unpack1('H*'), manifest: { segments: page.manifest.segments.to_s, selected: page.manifest.selected.to_s, value_count: page.manifest.value_count.to_s }, next: page.next&.data } }
        else raise 'Unsupported test operation'
        end
        puts JSON.generate(status: 0, value: result)
      rescue Transit::Error => error
        puts JSON.generate(status: error.status, value: { err: error.code, diagnostic: error.diagnostic, diagnostic_invalid: error.diagnostic_invalid })
      end
    end
  end
  puts JSON.generate(closed: true)
end
STDOUT.sync = true
mode, path = ARGV
config = JSON.parse(File.read(path))
mode == 'codecs' ? codecs(config) : serve(config)
