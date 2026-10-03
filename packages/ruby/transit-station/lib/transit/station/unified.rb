# frozen_string_literal: true
module Transit
  module Station
    # Typed callers over the shared signed v1 query implementation.
    module Unified
      TYPES = %i[int64 uint64 float64 boolean utf8 binary].freeze
      STATES = %i[missing null type_error value conflict].freeze
      PREDICATE_OPERATORS = %i[negate conjunction disjunction].freeze
      Scalar = Data.define(:type, :value) do
        def initialize(type:, value:)
          value = case type
          when :int64 then Internal.integer(value, min: -(1 << 63), max: (1 << 63)-1)
          when :uint64 then Internal.integer(value, min: 0, max: U64_MAX)
          when :float64
            raise ArgumentError, 'Expected finite float64' unless value.is_a?(Float) && value.finite?
            value
          when :boolean then Internal.boolean(value)
          when :utf8 then Internal.text(value, 4096).freeze
          when :binary then Internal.bytes(value, 4096).freeze
          else raise ArgumentError, 'Expected unified scalar type'
          end
          super(type: type, value: value)
        end
        def wire
          case type
          when :int64, :uint64 then { type.to_s => value.to_s }
          when :float64 then { 'float_bits' => [value].pack('E').unpack1('H*') }
          when :binary then { 'binary' => value.unpack1('H*') }
          else { type.to_s => value }
          end
        end
        def inspect = "#<Transit::Station::Unified::Scalar #{type}>"
      end
      Column = Data.define(:name, :type) do
        def initialize(name:, type:)
          raise ArgumentError, 'Expected query type' unless TYPES.include?(type)
          super(name: Internal.text(name, 64).freeze, type: type)
        end
        def wire = { 'name' => name, 'type' => type.to_s }
      end
      Decoder = Data.define(:type, :version) do
        def initialize(type:, version: 1)
          raise ArgumentError, 'Expected decoder type' unless TYPES.include?(type)
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
      TableSource = Data.define(:resource, :table, :names, :value_type) do
        def initialize(resource:, table:, names:, value_type:)
          raise ArgumentError, 'Expected Table resource, names and scalar type' unless resource.is_a?(ResourceRef) && names.is_a?(Array) && names.length == 2 && %i[int64 boolean utf8 binary].include?(value_type)
          super(resource: resource, table: Internal.integer(table, max: (1 << 32)-1),
            names: names.map { |name| Internal.text(name, 64).freeze }.freeze, value_type: value_type)
        end
        def wire = { 'version' => 1, 'resource' => resource.resource, 'source' => { 'table' => {
          'id' => table, 'names' => names, 'value_type' => value_type.to_s } } }
      end
      Projection = Data.define(:column, :path, :relative, :mode, :text_bytes, :text_steps) do
        def initialize(column:, path: [], relative: false, mode: :scalar, text_bytes: 4096, text_steps: 4096)
          raise ArgumentError, 'Expected projection' unless column.is_a?(Column) && %i[scalar text element_counter element_replica].include?(mode)
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
          super(column: Internal.integer(column, min: 0, max: 7), state: state)
        end
        def wire = { 'state' => { 'column' => column, 'value' => state.to_s } }
      end
      Compare = Data.define(:column, :comparison, :value) do
        def initialize(column:, comparison:, value:)
          raise ArgumentError, 'Expected comparison and scalar' unless %i[eq ne lt le gt ge].include?(comparison) && value.is_a?(Scalar)
          super(column: Internal.integer(column, min: 0, max: 7), comparison: comparison, value: value)
        end
        def wire = { 'compare' => { 'column' => column, 'op' => comparison.to_s, 'value' => value.wire } }
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
          raise ArgumentError, 'Expected bounded projection' unless projection.is_a?(Array) && projection.length.between?(1, 8)
          raise ArgumentError, 'Output names must match the projection width' unless output_names.nil? || (output_names.is_a?(Array) && output_names.length == projection.length)
          raise ArgumentError, 'Expected predicate' unless predicate.nil? || predicate.is_a?(IsState) || predicate.is_a?(Compare) || predicate.is_a?(PredicateProgram)
          raise ArgumentError, 'Expected aggregate' unless %i[rows count sum count_values].include?(aggregate)
          super(projection: projection.map { |v| Internal.integer(v, min: 0, max: 7) }.freeze, predicate: predicate,
            limit: limit.nil? ? nil : Internal.integer(limit, min: 0, max: U64_MAX), aggregate: aggregate,
            output_names: output_names&.map { |v| v.nil? ? nil : Internal.text(v, 32).freeze }&.freeze)
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
        def initialize(data:) = super(data: Internal.bytes(data, 16384).freeze)
        def self.prepare(source, plan, budgets, native_host: nil)
          Values.source!(source)
          raise ArgumentError, 'Expected plan and budgets' unless plan.is_a?(Plan) && budgets.is_a?(Budgets)
          result = Values.codec({ 'prepare' => { 'source' => source.wire, 'plan' => plan.wire, 'limits' => budgets.wire } }, native_host).fetch('prepared')
          new(data: Internal.unhex(result.fetch('bytes'), 16384))
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
          super('Query admission is uncertain; retain the identical command', status: 6, code: cause.code, phase: :submit_query)
        end
      end
      Connection = Data.define(:source, :resource, :requester, :requests) do
        def initialize(source:, resource:, requester:, requests:)
          unless source.is_a?(ProcessRef) && requester.is_a?(ProcessRef) && resource.is_a?(ResourceRef) && requests.is_a?(ResourceRef) &&
              [source.realm, resource.realm, requester.realm, requests.realm].uniq.length == 1
            raise ArgumentError, 'Query connection requires one realm'
          end
          super
        end
        def wire(principal) = { 'realm' => source.realm, 'principal' => principal, 'source' => source.pid,
          'resource' => resource.resource, 'requester' => requester.pid, 'requests' => requests.resource }
      end
      Alternative = Data.define(:counter, :replica, :state, :value, :actual_kind)
      Cell = Data.define(:state, :value, :actual_kind, :alternatives)
      Failure = Data.define(:code, :stage, :dimension, :limit, :observed)
      Status = Data.define(:phase, :correlation, :reference, :manifest, :collected, :failure)
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
      Manifest = Data.define(:job, :source, :requester, :correlation, :policy_revision, :request, :source_kind, :resource, :revision,
        :source_digest, :schema_digest, :plan_digest, :pages, :scanned, :selected, :value_count, :segments, :rows, :byte_count, :sum, :finished, :chain)
      Page = Data.define(:manifest, :columns, :ordinal, :rows, :ipc, :next) do
        def decode(native_host: nil) = Unified.decode_arrow(columns, ipc, rows, native_host: native_host)
        def inspect = "#<Transit::Station::Unified::Page ordinal=#{ordinal} rows=#{rows}>"
      end
      module Values
        module_function
        def path(value)
          raise ArgumentError, 'Expected bounded path' unless value.is_a?(Array) && value.length <= 8
          value.map { |name| Internal.text(name, 64).freeze }.freeze
        end
        def source!(value)
          raise ArgumentError, 'Expected declared source' unless value.is_a?(KVSource) || value.is_a?(TableSource) || value.is_a?(DocumentSource)
        end
        def columns(values) = values.map { |c| Column.new(name: c.fetch('name'), type: c.fetch('type').to_sym) }.freeze
        def inspected_atom(value)
          raise IncompatibleNative, 'Invalid inspected atom' unless value.is_a?(Hash) && value.length == 1
          kind, atom = value.first
          case kind
          when 'all'
            raise IncompatibleNative, 'Invalid all atom' unless atom == {}
            nil
          when 'state' then InspectedState.new(column: Internal.text(atom.fetch('column'), 32).freeze, state: atom.fetch('value').to_sym)
          when 'compare' then InspectedComparison.new(column: Internal.text(atom.fetch('column'), 32).freeze,
            comparison: atom.fetch('op').to_sym, type: atom.fetch('type').to_sym)
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
          when 'tables' then TableListing.new(names: data.map { |name| Internal.text(name, 32).freeze }.freeze)
          when 'explanation'
            selection = inspected_predicate(data.fetch('predicate'))
            limits = data.fetch('budgets')
            Explanation.new(operators: data.fetch('operators').map(&:to_sym).freeze, predicate: selection,
              projection: data.fetch('projection').map { |name| Internal.text(name, 32).freeze }.freeze,
              limit: data.fetch('limit').nil? ? nil : Value.wide(data.fetch('limit')), aggregate: data.fetch('aggregate').to_sym,
              columns: columns(data.fetch('columns')), budgets: Budgets.new(pages: Value.wide(limits.fetch('pages')),
                segments: Value.wide(limits.fetch('segments')), result_bytes: Value.wide(limits.fetch('result_bytes'))))
          else raise IncompatibleNative, 'Invalid SQL inspection details'
          end
          Inspection.new(name: Internal.text(v.fetch('name'), 32).freeze, resource: resource, source_kind: v.fetch('source_kind').to_sym,
            source_digest: Value.digest(v.fetch('contract')), schema_digest: Value.digest(v.fetch('schema')),
            resource_revision: Internal.integer(v.fetch('resource_revision'), min: 0), policy_revision: Value.wide(v.fetch('policy_revision'), min: 1), details: details)
        end
        def codec(action, native_host)
          worker = Internal::Worker.new { Bridge.local(native_host) }
          begin worker.call { |bridge| bridge.unified_codec(action) }
          ensure worker.close
          end
        end
        def scalar(value)
          type, payload = value.first
          case type
          when 'int64', 'uint64' then Scalar.new(type: type.to_sym, value: Integer(payload, 10))
          when 'float_bits' then Scalar.new(type: :float64, value: Internal.unhex(payload, 8).unpack1('E'))
          when 'binary' then Scalar.new(type: :binary, value: Internal.unhex(payload, 4096))
          else Scalar.new(type: type.to_sym, value: payload)
          end
        end
        def cell(value)
          state, payload = value.first
          alternatives = if state == 'conflict'
            payload.map do |item|
              nested = cell(item.fetch('value'))
              Alternative.new(counter: Value.wide(item.fetch('counter'), min: 1), replica: Value.wide(item.fetch('replica'), min: 1),
                state: nested.state, value: nested.value, actual_kind: nested.actual_kind)
            end.freeze
          else [].freeze
          end
          Cell.new(state: state.to_sym, value: state == 'value' ? scalar(payload) : nil,
            actual_kind: state == 'type_error' ? payload.to_sym : nil, alternatives: alternatives)
        end
        def page(v, realm)
          m, basis = v.fetch('manifest'), v.fetch('manifest').fetch('basis')
          raise IncompatibleNative, 'Unfinished result manifest' if m.fetch('finished').nil?
          manifest = Manifest.new(job: m.fetch('job'), source: Value.version(m.fetch('source')), requester: ProcessRef.new(realm: realm, pid: m.fetch('requester')),
            correlation: Value.wide(m.fetch('correlation')), policy_revision: Value.wide(m.fetch('policy_revision')),
            request: Internal.unhex(m.fetch('request'), 72).freeze, source_kind: basis.fetch('kind').to_sym,
            resource: ResourceRef.new(realm: realm, resource: basis.fetch('resource')), revision: basis.fetch('revision'),
            source_digest: Value.digest(basis.fetch('contract')), schema_digest: Value.digest(basis.fetch('schema')), plan_digest: Value.digest(m.fetch('plan')),
            pages: Value.wide(m.fetch('pages')), scanned: Value.wide(m.fetch('scanned')), selected: Value.wide(m.fetch('selected')),
            value_count: Value.wide(m.fetch('value_count')), segments: Value.wide(m.fetch('segments')), rows: Value.wide(m.fetch('rows')), byte_count: Value.wide(m.fetch('bytes')),
            sum: m.fetch('sum').nil? ? nil : Value.wide(m.fetch('sum'), min: -(1 << 63), max: (1 << 63)-1), finished: m.fetch('finished').to_sym, chain: Value.digest(m.fetch('chain')))
          Page.new(manifest: manifest, columns: v.fetch('columns').map { |c| Column.new(name: c.fetch('name'), type: c.fetch('type').to_sym) }.freeze,
            ordinal: Value.wide(v.fetch('ordinal')), rows: Internal.integer(v.fetch('rows'), min: 0, max: 8), ipc: Internal.unhex(v.fetch('ipc'), 65536).freeze,
            next: v.fetch('next').nil? ? nil : Cursor.new(data: v.fetch('next')))
        end
      end
      private_constant :Values
      def self.decode_arrow(columns, ipc, rows, native_host: nil)
        raise ArgumentError, 'Expected columns' unless columns.is_a?(Array) && columns.all? { |v| v.is_a?(Column) }
        value = Values.codec({ 'inspect_arrow' => { 'columns' => columns.map(&:wire), 'rows' => Internal.integer(rows, min: 0, max: 8),
          'ipc' => Internal.bytes(ipc, 65536).unpack1('H*') } }, native_host)
        value.fetch('rows').map { |row| row.map { |cell| Values.cell(cell) }.freeze }.freeze
      end
      class Client
        attr_reader :connection
        def self.open(config, credential, connection)
          owner = new(config, credential, connection)
          return owner unless block_given?
          begin yield owner
          ensure owner.close
          end
        end
        def initialize(config, credential, connection)
          unless config.is_a?(ClientConfig) && credential.is_a?(Credential) && connection.is_a?(Connection) && credential.realm == connection.source.realm
            raise ArgumentError, 'Expected configuration and credential matching the connection realm'
          end
          @connection = connection
          @worker = Internal::Worker.new do
            bridge = Bridge.new({ 'url' => config.url, 'seed_file' => credential.seed_file,
              'query_client' => { 'connection' => connection.wire(credential.principal), 'timeout_ms' => config.timeout_ms } }, config.native_host)
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
        def describe(source)
          Values.source!(source)
          raise ArgumentError, 'Source differs from the connection' unless source.resource == connection.resource
          v = call({ 'describe' => source.wire }).fetch('description')
          limits, caps = v.fetch('limits'), v.fetch('capabilities')
          Description.new(resource_revision: v.fetch('resource_revision'), policy_revision: Value.wide(v.fetch('policy_revision')),
            limits: Budgets.new(pages: Value.wide(limits.fetch('pages')), segments: Value.wide(limits.fetch('segments')), result_bytes: Value.wide(limits.fetch('result_bytes'))),
            active: v.fetch('active').nil? ? nil : Value.wide(v.fetch('active')), bundle_bytes: caps.fetch('bundle_bytes'), segment_bytes: caps.fetch('segment_bytes'), batch_rows: caps.fetch('batch_rows'))
        end
        def inspect_sql(source, name, sql, budgets)
          Values.source!(source)
          raise ArgumentError, 'Source differs from the connection' unless source.resource == connection.resource
          raise ArgumentError, 'Expected Budgets' unless budgets.is_a?(Budgets)
          result = call({ 'inspect' => { 'scope' => { 'source' => source.wire, 'name' => Internal.text(name, 32),
            'limits' => budgets.wire }, 'sql' => Internal.text(sql, 4096) } })
          Values.inspection(result.fetch('inspection'), connection.resource)
        end
        def compile_sql(source, name, sql, budgets, parameters: nil)
          Values.source!(source)
          raise ArgumentError, 'Source differs from the connection' unless source.resource == connection.resource
          raise ArgumentError, 'Expected Budgets' unless budgets.is_a?(Budgets)
          unless parameters.nil? || (parameters.is_a?(Array) && parameters.length <= 3)
            raise ArgumentError, 'Expected at most three parameter scalars'
          end
          values = parameters&.map do |value|
            raise ArgumentError, 'Expected Scalar' unless value.is_a?(Scalar)
            value.wire
          end
          result = call({ 'compile' => { 'scope' => { 'source' => source.wire, 'name' => Internal.text(name, 32),
            'limits' => budgets.wire }, 'sql' => Internal.text(sql, 4096), 'parameters' => values } })
          Bundle.new(data: Internal.unhex(result.fetch('compiled').fetch('bundle'), 16384))
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
            manifest: value.fetch('manifest').nil? ? nil : Internal.unhex(value.fetch('manifest'), 72).freeze, collected: value.fetch('collected'), failure: value.fetch('failure')&.then { |f| Failure.new(code: f.fetch('code').freeze, stage: f.fetch('stage').to_sym, dimension: f.fetch('dimension').to_sym, limit: Value.wide(f.fetch('limit')), observed: Value.wide(f.fetch('observed'))) })
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
