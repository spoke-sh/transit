# frozen_string_literal: true
require 'transit/station'
require 'json'
Q = Transit::Station::Unified
def check(value)
  raise 'Unified Ruby assertion failed' unless value
end
def codecs(config)
  resource = Transit::ResourceRef.new(realm: 46, resource: 7)
  sources = [Q::KVSource.new(resource: resource, prefix: 'data/', key: Q::Decoder.new(type: :binary), value: Q::Decoder.new(type: :uint64)),
    Q::TableSource.new(resource: resource, table: 9, names: %w[id label], value_type: :utf8),
    Q::DocumentSource.new(reference: Transit::Station::DocumentReference.new(resource: resource, document: (1 << 64)-1, epoch: 3, type_revision: 1, revision: 42),
      projections: [Q::Projection.new(column: Q::Column.new(name: 'title', type: :utf8), path: ['title']),
        Q::Projection.new(column: Q::Column.new(name: 'body', type: :utf8), path: ['body'], mode: :text)])]
  fixtures = JSON.parse(File.read(config.fetch('bundles')))
  sources.each_with_index do |source, index|
    scalar = index.zero? ? Q::Scalar.new(type: :uint64, value: (1 << 64)-1) : Q::Scalar.new(type: :utf8, value: 'x'*512)
    bundle = Q::Bundle.prepare(source, Q::Plan.new(projection: [1, 0], predicate: Q::Compare.new(column: 1, comparison: :ne, value: scalar), limit: (1 << 64)-1),
      Q::Budgets.new(pages: 1000, segments: 500, result_bytes: 1048576))
    check(bundle.data.unpack1('H*') == fixtures[index].fetch('wire_hex'))
    check(bundle.data.frozen?)
    named = Q::Bundle.prepare(source, Q::Plan.new(projection: [1, 0], output_names: ['Result', nil], predicate: Q::Compare.new(column: 1, comparison: :ne, value: scalar), limit: (1 << 64)-1),
      Q::Budgets.new(pages: 1000, segments: 500, result_bytes: 1048576))
    check(named.data.unpack1('H*') == fixtures[index].fetch('named_wire_hex'))
  end
  begin
    Q::Bundle.prepare(Q::KVSource.new(resource: resource, prefix: '', key: Q::Decoder.new(type: :binary, version: 2), value: Q::Decoder.new(type: :utf8)),
      Q::Plan.new(projection: [0]), Q::Budgets.new(pages: 1, segments: 1, result_bytes: 1))
    raise 'Unsupported decoder accepted'
  rescue Transit::Error
    nil
  end
  columns = %i[int64 uint64 float64 boolean utf8 binary].map { |type| Q::Column.new(name: type.to_s, type: type) }
  rows = Q.decode_arrow(columns, File.binread(config.fetch('arrow')), 5)
  check(rows.length == 5 && rows.all? { |row| row.length == 6 })
  Q::STATES.each_with_index { |state, index| check(rows[index].all? { |cell| cell.state == state }) }
  [-(1 << 63), (1 << 64)-1, -0.0, false, 'café é 東京🙂', "\0\xff\x80".b].each_with_index do |value, index|
    check(rows[3][index].value.value == value)
    alternatives = rows[4][index].alternatives
    check(alternatives.map { |v| [v.counter, v.replica, v.state] } == [[(1 << 64)-1, 1, :value], [(1 << 64)-1, 2, :null]])
    check(alternatives[0].value.value == value)
  end
  check([rows[3][2].value.value].pack('E').unpack1('H*') == '0000000000000080')
  check(Q.decode_arrow(columns, File.binread(config.fetch('empty')), 0) == [])
  begin
    Q.decode_arrow(columns, File.binread(config.fetch('malformed')), 5)
    raise 'Hidden Arrow value accepted'
  rescue Transit::Error
    nil
  end
  puts 'Ruby installed unified codecs: three sources, six types, five states and malformed rejection passed'
end
def serve(config)
  v = config.fetch('connection')
  resource = Transit::ResourceRef.new(realm: v.fetch('realm'), resource: v.fetch('resource'))
  connection = Q::Connection.new(source: Transit::ProcessRef.new(realm: v.fetch('realm'), pid: v.fetch('source')), resource: resource,
    requester: Transit::ProcessRef.new(realm: v.fetch('realm'), pid: v.fetch('requester')), requests: Transit::ResourceRef.new(realm: v.fetch('realm'), resource: v.fetch('requests')))
  source = case config.fetch('kind')
  when 'kv' then Q::KVSource.new(resource: resource, prefix: 'k', key: Q::Decoder.new(type: :binary), value: Q::Decoder.new(type: :utf8))
  when 'table' then Q::TableSource.new(resource: resource, table: 1, names: %w[id value], value_type: :utf8)
  else Q::DocumentSource.new(reference: Transit::Station::DocumentReference.new(resource: resource, document: 17, epoch: 1, type_revision: 1, revision: 13), expand: ['items'], projections: [
    Q::Projection.new(column: Q::Column.new(name: 'value', type: :utf8), relative: true),
    Q::Projection.new(column: Q::Column.new(name: 'counter', type: :uint64), relative: true, mode: :element_counter),
    Q::Projection.new(column: Q::Column.new(name: 'replica', type: :uint64), relative: true, mode: :element_replica),
    Q::Projection.new(column: Q::Column.new(name: 'optional', type: :utf8), path: ['optional'])])
  end
  doc = config.fetch('kind') == 'document'
  bundle = Q::Bundle.prepare(source, Q::Plan.new(projection: doc ? [0, 1, 2, 3] : [1], predicate:
    Q::Compare.new(column: doc ? 0 : 1, comparison: :ne, value: Q::Scalar.new(type: :utf8, value: 'x'*512))), Q::Budgets.new(pages: 1000, segments: 100, result_bytes: 1048576))
  check(bundle.data == File.binread(config.fetch('bundle')))
  cfg = Transit::ClientConfig.new(url: config.fetch('url'), profile: :native_v1, timeout_ms: 10000)
  credential = Transit::Credential.new(realm: v.fetch('realm'), principal: v.fetch('principal'), seed_file: config.fetch('seed_file'))
  Q::Client.open(cfg, credential, connection) do |client|
    description = client.describe(source)
    check(description.bundle_bytes == 16384 && description.batch_rows == 8)
    puts JSON.generate(ready: true)
    STDIN.each_line do |line|
      action = JSON.parse(line)
      break if action.key?('close')
      begin
        result = if action.key?('inspect')
          request = action.fetch('inspect')
          scope = request.fetch('scope')
          limits = scope.fetch('limits')
          value = client.inspect_sql(source, scope.fetch('name'), request.fetch('sql'), Q::Budgets.new(
            pages: Integer(limits.fetch('pages')), segments: Integer(limits.fetch('segments')), result_bytes: Integer(limits.fetch('result_bytes'))))
          check(value.resource == resource && value.source_kind.to_s == config.fetch('kind'))
          check(value.source_digest.frozen? && value.schema_digest.frozen? && value.details.frozen?)
          data = value.details
          details = case data
          when Q::SourceDescription then { description: { columns: data.columns.map(&:to_h) } }
          when Q::TableListing then { tables: data.names }
          when Q::Explanation
            predicate = case data.predicate
            when nil then { all: {} }
            when Q::InspectedState then { state: { column: data.predicate.column, value: data.predicate.state } }
            else { compare: { column: data.predicate.column, op: data.predicate.comparison, type: data.predicate.type } }
            end
            check(data.columns.frozen? && data.projection.frozen? && data.operators.frozen?)
            { explanation: { operators: data.operators, predicate: predicate, projection: data.projection, limit: data.limit&.to_s,
              aggregate: data.aggregate, columns: data.columns.map(&:to_h), budgets: data.budgets.to_h.transform_values(&:to_s) } }
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
          { status: status.nil? ? nil : { phase: status.phase, correlation: status.correlation.to_s } }
        elsif action.key?('page')
          value = action.fetch('page')
          page = client.page(Integer(value.fetch('namespace')), value['cursor'].nil? ? nil : Q::Cursor.new(data: value.fetch('cursor')))
          check(page.manifest.resource == resource && page.manifest.source_kind.to_s == config.fetch('kind'))
          check(page.decode.length == page.rows && page.ipc.frozen?)
          { page: { ordinal: page.ordinal.to_s, ipc: page.ipc.unpack1('H*'), manifest: { segments: page.manifest.segments.to_s }, next: page.next&.data } }
        else raise 'Unsupported test operation'
        end
        puts JSON.generate(status: 0, value: result)
      rescue Transit::Error => error
        puts JSON.generate(status: error.status, value: { err: error.code })
      end
    end
  end
  puts JSON.generate(closed: true)
end
STDOUT.sync = true
mode, path = ARGV
config = JSON.parse(File.read(path))
mode == 'codecs' ? codecs(config) : serve(config)
