# frozen_string_literal: true
module Transit
  module Station
    # Typed callers over the shared signed v1 query implementation.
    module Unified
      DECODER_TYPES = %i[int64 uint64 float64 boolean utf8 binary].freeze
      STATES = %i[missing null type_error value conflict].freeze
      PREDICATE_OPERATORS = %i[negate conjunction disjunction].freeze
      Scalar = Logical::Atom
      Column = Data.define(:name, :type, :nullable, :optional) do
        def initialize(name:, type:, nullable: false, optional: false)
          super(name: Values.name(name), type: Logical.descriptor(type), nullable: Internal.boolean(nullable), optional: Internal.boolean(optional))
        end
        def wire = { 'name' => name, 'type' => Logical.type_wire(type), 'nullable' => nullable, 'optional' => optional }
      end
      DecoderColumn = Data.define(:name, :type) do
        def initialize(name:, type:)
          raise ArgumentError, 'Expected decoder type' unless DECODER_TYPES.include?(type)
          super(name: Internal.text(name, 32).freeze, type: type)
        end
        def wire = { 'name' => name, 'type' => type.to_s }
      end
      Decoder = Data.define(:type, :version) do
        def initialize(type:, version: 1)
          raise ArgumentError, 'Expected decoder type' unless DECODER_TYPES.include?(type)
          super(type: type, version: Internal.integer(version, max: 255))
        end
        def wire = { 'type' => type.to_s, 'version' => version }
      end
      KVSource = Data.define(:resource, :prefix, :key, :value) do
        def initialize(resource:, prefix:, key:, value:)
          raise ArgumentError, 'Expected resource and decoders' unless resource.is_a?(ResourceRef) && key.is_a?(Decoder) && value.is_a?(Decoder)
          super(resource: resource, prefix: Internal.bytes(prefix, 32).freeze, key: key, value: value)
        end
        def wire = { 'version' => 1, 'resource' => resource.resource, 'source' => { 'kv' => {
          'prefix' => prefix.unpack1('H*'), 'key' => key.wire, 'value' => value.wire } } }
      end
      TableInterpretation = Data.define(:revision, :digest, :byte_count, :schema_digest) do
        def initialize(revision:, digest:, byte_count:, schema_digest:)
          super(revision: Internal.integer(revision, max: U64_MAX), digest: Values.commitment(digest),
            byte_count: Internal.integer(byte_count, max: U64_MAX), schema_digest: Values.commitment(schema_digest))
        end
        def wire = { 'revision' => revision.to_s, 'digest' => digest.bytes, 'bytes' => byte_count.to_s, 'schema' => schema_digest.bytes }
      end
      TableSource = Data.define(:scope, :audience, :branch, :namespace, :interpretation, :schema) do
        def initialize(scope:, audience:, branch:, namespace:, interpretation:, schema:)
          unless scope.is_a?(Catalog::Scope) && interpretation.is_a?(TableInterpretation) && schema.is_a?(Catalog::Schema)
            raise ArgumentError, 'Expected a direct Table interpretation and schema'
          end
          super(scope: scope, audience: Internal.integer(audience), branch: Internal.integer(branch, max: U64_MAX),
            namespace: Internal.integer(namespace), interpretation: interpretation, schema: schema)
        end
        def resource = scope.resource
        def wire
          row_type = Logical::Structure.new(fields: schema.columns.map do |column|
            Logical::Field.new(name: column.name, type: column.type, nullable: column.nullable)
          end)
          { 'version' => 1, 'resource' => resource.resource, 'source' => { 'table' => {
            'scope' => scope.wire, 'owner' => audience, 'branch' => branch.to_s, 'namespace' => namespace, 'object' => schema.object.to_s,
            'interpretation' => interpretation.wire, 'row_type' => Logical.type_wire(row_type),
            'collations' => schema.columns.map { |column| column.collation.to_s } } } }
        end
      end
      Tables = Data.define(:url, :scope, :branch, :audience) do
        def initialize(url:, scope:, branch:, audience:)
          raise ArgumentError, 'Expected catalog scope' unless scope.is_a?(Catalog::Scope)
          super(url: Internal.text(url, 2048).freeze, scope: scope, branch: Internal.integer(branch, max: U64_MAX), audience: Internal.integer(audience))
        end
        def wire(credential, connection)
          raise ArgumentError, 'Direct Tables must use the query realm' unless scope.resource.realm == connection.source.realm
          { 'url' => url, 'connection' => { 'scope' => scope.wire, 'branch' => branch.to_s, 'audience' => audience,
            'principal' => credential.principal, 'role' => connection.role } }
        end
      end
      Capture = Data.define(:executor, :operation, :partition, :next_lsn) do
        def initialize(executor:, operation:, partition:, next_lsn:)
          super(executor: Internal.integer(executor), operation: Internal.integer(operation, max: U64_MAX),
            partition: Internal.integer(partition, max: U64_MAX), next_lsn: Internal.integer(next_lsn, min: 0, max: U64_MAX))
        end
        def wire = { 'executor' => executor, 'operation' => operation.to_s, 'expected' => { 'partition' => partition.to_s, 'next_lsn' => next_lsn.to_s } }
      end
      TableDefinition = Data.define(:source, :partition, :next_lsn) do
        def initialize(source:, partition:, next_lsn:)
          raise ArgumentError, 'Expected direct Table source' unless source.is_a?(TableSource)
          super(source: source, partition: Internal.integer(partition, max: U64_MAX), next_lsn: Internal.integer(next_lsn, min: 0, max: U64_MAX))
        end
        def capture(executor:, operation:) = Capture.new(executor: executor, operation: operation, partition: partition, next_lsn: next_lsn)
      end
      Projection = Data.define(:column, :path, :relative, :mode, :text_bytes, :text_steps) do
        def initialize(column:, path: [], relative: false, mode: :scalar, text_bytes: 4096, text_steps: 4096)
          raise ArgumentError, 'Expected projection' unless column.is_a?(DecoderColumn) && %i[scalar text element_counter element_replica].include?(mode)
          super(column: column, path: Values.path(path), relative: Internal.boolean(relative), mode: mode,
            text_bytes: Internal.integer(text_bytes, max: 4096), text_steps: Internal.integer(text_steps, max: 16384))
        end
        def wire = { 'column' => column.wire, 'path' => path, 'relative' => relative,
          'mode' => mode.to_s, 'text_bytes' => text_bytes, 'text_steps' => text_steps }
      end
      DocumentSource = Data.define(:reference, :projections, :expand) do
        def initialize(reference:, projections:, expand: nil)
          raise ArgumentError, 'Expected accepted reference and projections' unless reference.is_a?(DocumentReference) && projections.is_a?(Array) && projections.length.between?(1, 8) && projections.all? { |v| v.is_a?(Projection) }
          super(reference: reference, projections: projections.dup.freeze, expand: expand.nil? ? nil : Values.path(expand))
        end
        def resource = reference.resource
        def wire
          ref = reference
          { 'version' => 1, 'resource' => resource.resource, 'source' => { 'document' => {
            'reference' => { 'resource' => resource.resource, 'document' => ref.document.to_s, 'epoch' => ref.epoch.to_s,
              'type_revision' => ref.type_revision, 'revision' => ref.revision.to_s }, 'change_format' => 1,
            'expand' => expand, 'projections' => projections.map(&:wire) } } }
        end
      end
      IsState = Data.define(:column, :state) do
        def initialize(column:, state:)
          raise ArgumentError, 'Expected cell state' unless STATES.include?(state)
          super(column: Internal.integer(column, min: 0, max: 127), state: state)
        end
        def wire = { 'state' => { 'column' => column, 'value' => state.to_s } }
      end
      Compare = Data.define(:column, :comparison, :value) do
        def initialize(column:, comparison:, value:)
          raise ArgumentError, 'Expected comparison and scalar' unless %i[eq ne lt le gt ge].include?(comparison) && value.is_a?(Scalar)
          super(column: Internal.integer(column, min: 0, max: 127), comparison: comparison, value: value)
        end
        def wire = { 'compare' => { 'column' => column, 'op' => comparison.to_s, 'value' => Values.scalar_wire(value) } }
      end
      PredicateAtom = Data.define(:predicate) do
        def initialize(predicate: nil)
          raise ArgumentError, 'Expected a non-program predicate atom' unless predicate.nil? || predicate.is_a?(IsState) || predicate.is_a?(Compare)
          super(predicate: predicate)
        end
        def wire = { 'atom' => predicate&.wire || { 'all' => {} } }
      end
      PredicateProgram = Data.define(:instructions) do
        def initialize(instructions:)
          unless instructions.is_a?(Array) && instructions.length.between?(1, 64) &&
              instructions.all? { |v| v.is_a?(PredicateAtom) || PREDICATE_OPERATORS.include?(v) }
            raise ArgumentError, 'Expected one to 64 predicate atoms/operators'
          end
          super(instructions: instructions.dup.freeze)
        end
        def wire = { 'program' => instructions.map { |v| v.is_a?(PredicateAtom) ? v.wire : { v.to_s => {} } } }
      end
      Plan = Data.define(:projection, :predicate, :limit, :aggregate, :output_names) do
        def initialize(projection:, predicate: nil, limit: nil, aggregate: :rows, output_names: nil)
          raise ArgumentError, 'Expected bounded projection' unless projection.is_a?(Array) && projection.length.between?(1, 128)
          raise ArgumentError, 'Output names must match the projection width' unless output_names.nil? || (output_names.is_a?(Array) && output_names.length == projection.length)
          raise ArgumentError, 'Expected predicate' unless predicate.nil? || predicate.is_a?(IsState) || predicate.is_a?(Compare) || predicate.is_a?(PredicateProgram)
          raise ArgumentError, 'Expected aggregate' unless %i[rows count sum count_values].include?(aggregate)
          super(projection: projection.map { |v| Internal.integer(v, min: 0, max: 127) }.freeze, predicate: predicate,
            limit: limit.nil? ? nil : Internal.integer(limit, min: 0, max: U64_MAX), aggregate: aggregate,
            output_names: output_names&.map { |v| v.nil? ? nil : Values.name(v) }&.freeze)
        end
        def wire = { 'version' => 1, 'projection' => projection, 'predicate' => predicate&.wire || { 'all' => {} },
          'limit' => limit&.to_s, 'aggregate' => aggregate.to_s, 'output_names' => output_names }
      end
      Budgets = Data.define(:pages, :segments, :result_bytes) do
        def initialize(pages:, segments:, result_bytes:)
          super(pages: Internal.integer(pages, max: U64_MAX), segments: Internal.integer(segments, max: U64_MAX), result_bytes: Internal.integer(result_bytes, max: U64_MAX))
        end
        def wire = { 'pages' => pages.to_s, 'segments' => segments.to_s, 'result_bytes' => result_bytes.to_s }
      end
      Bundle = Data.define(:data) do
        def initialize(data:) = super(data: Internal.bytes(data, 25614).freeze)
        def self.prepare(source, plan, budgets, native_host: nil)
          Values.source!(source)
          raise ArgumentError, 'Expected plan and budgets' unless plan.is_a?(Plan) && budgets.is_a?(Budgets)
          declaration, parameters = source.wire, plan.wire
          parameters['collations'] = declaration.fetch('source').fetch('table').fetch('collations') if source.is_a?(TableSource)
          result = Values.codec({ 'prepare' => { 'source' => declaration, 'plan' => parameters, 'limits' => budgets.wire } }, native_host).fetch('prepared')
          new(data: Internal.unhex(result.fetch('bytes'), 25614))
        end
        def inspect = '#<Transit::Station::Unified::Bundle>'
      end
      Prepared = Data.define(:data) do
        def initialize(data:) = super(data: Internal.text(data, 8192).freeze)
        def inspect = '#<Transit::Station::Unified::Prepared>'
      end
      Cursor = Data.define(:data) do
        def initialize(data:) = super(data: Internal.text(data, 4096).freeze)
        def inspect = '#<Transit::Station::Unified::Cursor>'
      end
      class Uncertain < UnknownOutcome
        attr_reader :prepared
        def initialize(prepared, cause)
          @prepared = prepared
          super('Query admission is uncertain; retain the identical command', status: 6, code: cause.code, phase: :submit_query, diagnostic: cause.diagnostic, diagnostic_invalid: cause.diagnostic_invalid)
        end
      end
      Connection = Data.define(:source, :resource, :requester, :requests, :role) do
        def initialize(source:, resource:, requester:, requests:, role: nil)
          unless source.is_a?(ProcessRef) && requester.is_a?(ProcessRef) && resource.is_a?(ResourceRef) && requests.is_a?(ResourceRef) &&
              [source.realm, resource.realm, requester.realm, requests.realm].uniq.length == 1
            raise ArgumentError, 'Query connection requires one realm'
          end
          Internal.integer(role, min: 0) unless role.nil?
          super
        end
        def wire(principal) = { 'realm' => source.realm, 'principal' => principal, 'source' => source.pid,
          'resource' => resource.resource, 'requester' => requester.pid, 'requests' => requests.resource, 'role' => role }
      end
      Failure = Data.define(:code, :stage, :dimension, :limit, :observed)
      Status = Data.define(:phase, :correlation, :reference, :manifest, :collected, :failure, :diagnostic)
      Observation = Data.define(:state, :reason)
      Description = Data.define(:resource_revision, :policy_revision, :limits, :active, :bundle_bytes, :segment_bytes, :batch_rows)
      InspectedState = Data.define(:column, :state)
      InspectedComparison = Data.define(:column, :comparison, :type)
      InspectedAtom = Data.define(:predicate)
      InspectedProgram = Data.define(:instructions)
      SourceDescription = Data.define(:columns)
      TableListing = Data.define(:names)
      Explanation = Data.define(:operators, :predicate, :projection, :limit, :aggregate, :columns, :budgets)
      Inspection = Data.define(:name, :resource, :source_kind, :source_digest, :schema_digest, :resource_revision, :policy_revision, :details)
      NativeCut = Data.define(:revision) do
        def initialize(revision:) = super(revision: Internal.integer(revision, min: 0))
      end
      TableCut = Data.define(:commitment) do
        def initialize(commitment:) = super(commitment: Values.commitment(commitment))
      end
      Manifest = Data.define(:job, :source, :requester, :correlation, :policy_revision, :request, :source_kind, :resource, :cut,
         :source_digest, :schema_digest, :plan_digest, :pages, :scanned, :selected, :value_count, :segments, :rows, :byte_count, :sum, :finished, :chain)
      Page = Data.define(:manifest, :columns, :ordinal, :rows, :ipc, :next) do
        def decode(native_host: nil) = Unified.decode_arrow(columns, ipc, rows, native_host: native_host)
        def inspect = "#<Transit::Station::Unified::Page ordinal=#{ordinal} rows=#{rows}>"
      end
      module Values
        module_function
        def commitment(value)
          result = Internal.bytes(value, 32).freeze
          raise ArgumentError, 'Expected 32-byte commitment' unless result.bytesize == 32
          result
        end
        def table(value)
          return nil if value.nil?
          envelope = value.fetch('source'); direct = envelope.fetch('source').fetch('table'); interpretation = direct.fetch('interpretation')
          source = TableSource.new(scope: Internal.catalog_scope(direct.fetch('scope')), audience: direct.fetch('owner'),
            branch: Value.wide(direct.fetch('branch'), min: 1), namespace: direct.fetch('namespace'),
            interpretation: TableInterpretation.new(revision: Value.wide(interpretation.fetch('revision'), min: 1),
              digest: Value.digest(interpretation.fetch('digest')), byte_count: Value.wide(interpretation.fetch('bytes'), min: 1),
              schema_digest: Value.digest(interpretation.fetch('schema'))), schema: Internal.catalog_schema(value.fetch('schema')))
          raise IncompatibleNative, 'Inconsistent direct Table definition' unless source.wire == envelope
          TableDefinition.new(source: source, partition: Value.wide(value.fetch('expected').fetch('partition'), min: 1),
            next_lsn: Value.wide(value.fetch('expected').fetch('next_lsn')))
        end
        def name(value)
          result = Internal.text(value, 255).freeze
          raise ArgumentError, 'Expected a nonempty query name without NUL' if result.empty? || result.include?("\0")
          result
        end
        def path(value)
          raise ArgumentError, 'Expected bounded path' unless value.is_a?(Array) && value.length <= 8
          value.map { |name| Internal.text(name, 64).freeze }.freeze
        end
        def source!(value)
          raise ArgumentError, 'Expected declared source' unless value.is_a?(KVSource) || value.is_a?(TableSource) || value.is_a?(DocumentSource)
        end
        def columns(values) = Logical.collection(values.map { |c| Column.new(name: c.fetch('name'), type: Logical.type_from_wire(c.fetch('type')), nullable: c.fetch('nullable'), optional: c.fetch('optional')) }, Column, 128)
        def inspected_atom(value)
          raise IncompatibleNative, 'Invalid inspected atom' unless value.is_a?(Hash) && value.length == 1
          kind, atom = value.first
          case kind
          when 'all'
            raise IncompatibleNative, 'Invalid all atom' unless atom == {}
            nil
          when 'state' then InspectedState.new(column: name(atom.fetch('column')), state: atom.fetch('value').to_sym)
          when 'compare' then InspectedComparison.new(column: name(atom.fetch('column')),
            comparison: atom.fetch('op').to_sym, type: Logical.type_from_wire(atom.fetch('type')))
          else raise IncompatibleNative, 'Invalid inspected atom'
          end
        end
        def inspected_predicate(value)
          raise IncompatibleNative, 'Invalid inspected predicate' unless value.is_a?(Hash) && value.length == 1
          return inspected_atom(value) unless value.key?('program')
          program = value.fetch('program')
          raise IncompatibleNative, 'Invalid inspected program size' unless program.is_a?(Array) && program.length.between?(1, 64)
          depth = 0
          instructions = program.map do |instruction|
            raise IncompatibleNative, 'Invalid inspected instruction' unless instruction.is_a?(Hash) && instruction.length == 1
            kind, payload = instruction.first
            if kind == 'atom'
              depth += 1
              InspectedAtom.new(predicate: inspected_atom(payload))
            else
              operator = kind.to_sym
              needed = operator == :negate ? 1 : 2
              unless PREDICATE_OPERATORS.include?(operator) && payload == {} && depth >= needed
                raise IncompatibleNative, 'Invalid inspected program shape'
              end
              depth -= needed - 1
              operator
            end
          end
          raise IncompatibleNative, 'Invalid inspected program shape' unless depth == 1
          InspectedProgram.new(instructions: instructions.freeze)
        end
        def inspection(v, resource)
          unless v.fetch('version') == 1 && v.fetch('scope') == 'configured_source' && v.fetch('resource') == resource.resource
            raise IncompatibleNative, 'Invalid SQL inspection scope'
          end
          variant, data = v.fetch('details').first
          details = case variant
          when 'description' then SourceDescription.new(columns: columns(data.fetch('columns')))
          when 'tables' then TableListing.new(names: data.map { |name| Values.name(name) }.freeze)
          when 'explanation'
            selection = inspected_predicate(data.fetch('predicate'))
            limits = data.fetch('budgets')
            Explanation.new(operators: data.fetch('operators').map(&:to_sym).freeze, predicate: selection,
              projection: data.fetch('projection').map { |name| Values.name(name) }.freeze,
              limit: data.fetch('limit').nil? ? nil : Value.wide(data.fetch('limit')), aggregate: data.fetch('aggregate').to_sym,
              columns: columns(data.fetch('columns')), budgets: Budgets.new(pages: Value.wide(limits.fetch('pages')),
                segments: Value.wide(limits.fetch('segments')), result_bytes: Value.wide(limits.fetch('result_bytes'))))
          else raise IncompatibleNative, 'Invalid SQL inspection details'
          end
          Inspection.new(name: name(v.fetch('name')), resource: resource, source_kind: v.fetch('source_kind').to_sym,
            source_digest: Value.digest(v.fetch('contract')), schema_digest: Value.digest(v.fetch('schema')),
            resource_revision: Internal.integer(v.fetch('resource_revision'), min: 0), policy_revision: Value.wide(v.fetch('policy_revision'), min: 1), details: details)
        end
        def codec(action, native_host)
          worker = Internal::Worker.new { Bridge.local(native_host) }
          begin worker.call { |bridge| bridge.unified_codec(action) }
          ensure worker.close
          end
        end
        def scalar_wire(value)
          if value.is_a?(Scalar) && %i[utf8 binary].include?(value.kind) && value.value.bytesize > 4096
            raise ArgumentError, 'Query literal exceeds 4096 bytes'
          end
          Logical.atom_wire(value)
        end
        def page(v, realm)
          m, basis = v.fetch('manifest'), v.fetch('manifest').fetch('basis')
          cut = basis.fetch('cut')
          raise IncompatibleNative, 'Unfinished result manifest' if m.fetch('finished').nil?
          retention, position = m.fetch('source'), cut.fetch('position')
          if cut.fetch('kind') == 'table'
            raise IncompatibleNative, 'Invalid direct Table cut' unless retention.keys == ['table'] && position.keys == ['table']
            source = ProcessRef.new(realm: realm, pid: retention.fetch('table').fetch('worker'))
            captured = TableCut.new(commitment: Value.digest(position.fetch('table')))
          else
            raise IncompatibleNative, 'Invalid native source cut' unless %w[kv document].include?(cut.fetch('kind')) && retention.keys == ['native'] && position.keys == ['native_revision']
            source = Value.version(retention.fetch('native'))
            captured = NativeCut.new(revision: position.fetch('native_revision'))
          end
          manifest = Manifest.new(job: m.fetch('job'), source: source, requester: ProcessRef.new(realm: realm, pid: m.fetch('requester')),
            correlation: Value.wide(m.fetch('correlation')), policy_revision: Value.wide(m.fetch('policy_revision')),
            request: Internal.unhex(m.fetch('request'), 72).freeze, source_kind: cut.fetch('kind').to_sym,
            resource: ResourceRef.new(realm: realm, resource: cut.fetch('resource')), cut: captured,
            source_digest: Value.digest(basis.fetch('contract')), schema_digest: Value.digest(basis.fetch('schema')), plan_digest: Value.digest(m.fetch('plan')),
            pages: Value.wide(m.fetch('pages')), scanned: Value.wide(m.fetch('scanned')), selected: Value.wide(m.fetch('selected')),
            value_count: Value.wide(m.fetch('value_count')), segments: Value.wide(m.fetch('segments')), rows: Value.wide(m.fetch('rows')), byte_count: Value.wide(m.fetch('bytes')),
            sum: m.fetch('sum').nil? ? nil : Value.wide(m.fetch('sum'), min: -(1 << 63), max: (1 << 63)-1), finished: m.fetch('finished').to_sym, chain: Value.digest(m.fetch('chain')))
          Page.new(manifest: manifest, columns: columns(v.fetch('columns')),
            ordinal: Value.wide(v.fetch('ordinal')), rows: Internal.integer(v.fetch('rows'), min: 0, max: 8), ipc: Internal.unhex(v.fetch('ipc'), 65536).freeze,
            next: v.fetch('next').nil? ? nil : Cursor.new(data: v.fetch('next')))
        end
      end
      private_constant :Values
      def self.decode_arrow(columns, ipc, rows, native_host: nil)
        raise ArgumentError, 'Expected columns' unless columns.is_a?(Array) && columns.length.between?(1, 128) && columns.all? { |v| v.is_a?(Column) }
        value = Values.codec({ 'inspect_arrow' => { 'columns' => columns.map(&:wire), 'rows' => Internal.integer(rows, min: 0, max: 8),
          'ipc' => Internal.bytes(ipc, 65536).unpack1('H*') } }, native_host)
        value.fetch('rows').map { |row| row.map { |cell| Logical.cell_from_wire(cell) }.freeze }.freeze
      end
      class Client
        attr_reader :connection
        def self.open(config, credential, connection, tables: nil)
          owner = new(config, credential, connection, tables: tables)
          return owner unless block_given?
          begin yield owner
          ensure owner.close
          end
        end
        def initialize(config, credential, connection, tables: nil)
          unless config.is_a?(ClientConfig) && credential.is_a?(Credential) && connection.is_a?(Connection) && credential.realm == connection.source.realm
            raise ArgumentError, 'Expected configuration and credential matching the connection realm'
          end
          raise ArgumentError, 'Expected direct Table endpoint' unless tables.nil? || tables.is_a?(Tables)
          @connection = connection
          @worker = Internal::Worker.new do
            bridge = Bridge.new({ 'url' => config.url, 'seed_file' => credential.seed_file,
              'query_client' => { 'connection' => connection.wire(credential.principal), 'timeout_ms' => config.timeout_ms, 'tables' => tables&.wire(credential, connection) } }, config.native_host)
            begin
              caps = bridge.unified_query({ 'capabilities' => {} }).fetch('capabilities')
              raise UnsupportedCapability, 'Native query caller lacks v1 sources' unless caps['version'] == 1 && %w[kv table document].all? { |kind| caps[kind] }
              bridge
            rescue Exception
              bridge.close
              raise
            end
          end
        end
        def lookup_table(name, namespace: 1)
          Values.table(call({ 'table' => { 'namespace' => Internal.integer(namespace), 'name' => Values.name(name) } }).fetch('table'))
        end
        def describe(source)
          Values.source!(source)
          raise ArgumentError, 'Source differs from the connection' unless source.resource.realm == connection.resource.realm && (source.is_a?(TableSource) || source.resource == connection.resource)
          v = call({ 'describe' => source.wire }).fetch('description')
          limits, caps = v.fetch('limits'), v.fetch('capabilities')
          Description.new(resource_revision: v.fetch('resource_revision'), policy_revision: Value.wide(v.fetch('policy_revision')),
            limits: Budgets.new(pages: Value.wide(limits.fetch('pages')), segments: Value.wide(limits.fetch('segments')), result_bytes: Value.wide(limits.fetch('result_bytes'))),
            active: v.fetch('active').nil? ? nil : Value.wide(v.fetch('active')), bundle_bytes: caps.fetch('bundle_bytes'), segment_bytes: caps.fetch('segment_bytes'), batch_rows: caps.fetch('batch_rows'))
        end
        def inspect_sql(source, name, sql, budgets)
          Values.source!(source)
          raise ArgumentError, 'Source differs from the connection' unless source.resource.realm == connection.resource.realm && (source.is_a?(TableSource) || source.resource == connection.resource)
          raise ArgumentError, 'Expected Budgets' unless budgets.is_a?(Budgets)
          result = call({ 'inspect' => { 'scope' => { 'source' => source.wire, 'name' => Values.name(name),
            'limits' => budgets.wire }, 'sql' => Internal.text(sql, 4096) } })
          Values.inspection(result.fetch('inspection'), source.resource)
        end
        def compile_sql(source, name, sql, budgets, parameters: nil)
          Values.source!(source)
          raise ArgumentError, 'Source differs from the connection' unless source.resource.realm == connection.resource.realm && (source.is_a?(TableSource) || source.resource == connection.resource)
          raise ArgumentError, 'Expected Budgets' unless budgets.is_a?(Budgets)
          unless parameters.nil? || (parameters.is_a?(Array) && parameters.length <= 65)
            raise ArgumentError, 'Expected at most 65 parameter atoms'
          end
          values = parameters&.map do |value|
            raise ArgumentError, 'Expected Scalar' unless value.is_a?(Scalar)
            Values.scalar_wire(value)
          end
          result = call({ 'compile' => { 'scope' => { 'source' => source.wire, 'name' => Values.name(name),
            'limits' => budgets.wire }, 'sql' => Internal.text(sql, 4096), 'parameters' => values } })
          Bundle.new(data: Internal.unhex(result.fetch('compiled').fetch('bundle'), 25614))
        end
        # Seal new work before persistence. Saved bundles keep their original proof.
        def authorize_bundle(bundle, capture: nil)
          raise ArgumentError, 'Expected Bundle' unless bundle.is_a?(Bundle)
          raise ArgumentError, 'Expected explicit Table capture' unless capture.nil? || capture.is_a?(Capture)
          Bundle.new(data: Internal.unhex(call({ 'authorize' => { 'bundle' => bundle.data.unpack1('H*'), 'capture' => capture&.wire } }).fetch('authorized'), 25614))
        end
        def prepare_cleanup(namespace, bundle)
          raise ArgumentError, 'Expected original Bundle' unless bundle.is_a?(Bundle)
          value = call({ 'cleanup' => { 'namespace' => Internal.integer(namespace, max: U64_MAX).to_s, 'bundle' => bundle.data.unpack1('H*') } }).fetch('prepared')
          raise IncompatibleNative, 'Missing cleanup command' if value.nil?
          Prepared.new(data: value)
        end
        def prepare_next(namespace, bundle)
          raise ArgumentError, 'Expected Bundle' unless bundle.is_a?(Bundle)
          v = call({ 'next' => { 'namespace' => Internal.integer(namespace, max: U64_MAX).to_s, 'bundle' => bundle.data.unpack1('H*') } }).fetch('prepared')
          v.nil? ? nil : Prepared.new(data: v)
        end
        def prepare_cancel(namespace) = control('cancel', namespace)
        def prepare_retire(namespace) = control('retire', namespace)
        def prepare_collect(namespace) = control('collect', namespace)
        def submit(prepared)
          raise ArgumentError, 'Expected persisted Prepared command' unless prepared.is_a?(Prepared)
          result = call({ 'submit' => prepared.data })
          raise UnknownOutcome, 'Missing admission receipt' unless result.key?('receipt')
          Internal.integer(result.fetch('receipt').fetch('position'))
        rescue UnknownOutcome => error
          raise Uncertain.new(prepared, error), cause: error
        end
        def observe(position)
          value = call({ 'observe' => Internal.integer(position) }).fetch('observation')
          name, payload = value.first
          Observation.new(state: name.to_sym, reason: name == 'rejected' ? Internal.text(Internal.unhex(payload, 256), 256).freeze : nil)
        end
        def status(namespace)
          value = call({ 'status' => Internal.integer(namespace, max: U64_MAX).to_s }).fetch('status')
          return nil if value.nil?
          Status.new(phase: value.fetch('phase').to_sym, correlation: Value.wide(value.fetch('correlation')),
            reference: Internal.unhex(value.fetch('reference'), 72).freeze,
            manifest: value.fetch('manifest').nil? ? nil : Internal.unhex(value.fetch('manifest'), 72).freeze, collected: value.fetch('collected'), diagnostic: value.fetch('diagnostic'), failure: value.fetch('failure')&.then { |f| Failure.new(code: f.fetch('code').freeze, stage: f.fetch('stage').to_sym, dimension: f.fetch('dimension').to_sym, limit: Value.wide(f.fetch('limit')), observed: Value.wide(f.fetch('observed'))) })
        end
        def page(namespace, cursor = nil)
          raise ArgumentError, 'Expected Cursor' unless cursor.nil? || cursor.is_a?(Cursor)
          Values.page(call({ 'page' => { 'namespace' => Internal.integer(namespace, max: U64_MAX).to_s, 'cursor' => cursor&.data } }).fetch('page'), connection.source.realm)
        end
        def close = @worker.close
        private
        def call(action) = @worker.call { |bridge| bridge.unified_query(action) }
        def control(name, namespace)
          value = call({ 'prepare' => { name => Internal.integer(namespace, max: U64_MAX).to_s } }).fetch('prepared')
          raise IncompatibleNative, 'Missing prepared command' if value.nil?
          Prepared.new(data: value)
        end
      end
    end
  end
end
