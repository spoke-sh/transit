# frozen_string_literal: true
module Transit
  module Station
    # Host values and scheduling over the shared signed catalog caller.
    module Catalog
      module Values
        module_function
        def typed(value, type)
          raise ArgumentError, 'Expected a typed catalog value' unless value.is_a?(type)
          value
        end
        def name(value)
          result = Internal.text(value, 16).freeze
          raise ArgumentError, 'Empty catalog name' if result.empty?
          result
        end
        def catalog_name(value)
          result = name(value)
          raise ArgumentError, 'Expected an ASCII catalog name' unless /\A[A-Za-z_][A-Za-z_0-9]*\z/.match?(result)
          result
        end
        def object(value, fields)
          raise IncompatibleNative, 'Invalid catalog response fields' unless value.is_a?(Hash) && value.keys.sort == fields.sort
          value
        end
        def result(value, tag) = object(value, [tag]).fetch(tag)
        def enum(value, names)
          raise IncompatibleNative, 'Unknown catalog result' unless names.include?(value)
          value.to_sym
        end
        def scope(value)
          v = object(value, %w[realm resource catalog])
          Scope.new(resource: ResourceRef.new(realm: v.fetch('realm'), resource: v.fetch('resource')),
            catalog: Value.wide(v.fetch('catalog'), min: 1))
        end
        def configuration(value)
          v = object(value, %w[scope owner administrator]); s = scope(v.fetch('scope'))
          Configuration.new(scope: s, owner: ProcessRef.new(realm: s.resource.realm, pid: v.fetch('owner')),
            administrator: v.fetch('administrator'))
        end
        def policy(value)
          v = object(value, %w[scope principal revision inspect create])
          Policy.new(scope: scope(v.fetch('scope')), principal: v.fetch('principal'),
            revision: Value.wide(v.fetch('revision'), min: 1), can_inspect: v.fetch('inspect'), can_create: v.fetch('create'))
        end
        def request(value)
          v = object(value, %w[scope operation object table name schema])
          schema = object(v.fetch('schema'), %w[names value_type])
          kind = enum(schema.fetch('value_type'), %w[int64 boolean utf8 binary])
          CreateTable.new(scope: scope(v.fetch('scope')), operation: Value.wide(v.fetch('operation'), min: 1),
            object: Value.wide(v.fetch('object'), min: 1), table: v.fetch('table'), name: v.fetch('name'),
            schema: Schema.new(names: schema.fetch('names'), value_type: kind))
        end
        def definition(value)
          return nil if value.nil?
          v = object(value, %w[scope object revision name source principal operation input])
          table = object(object(v.fetch('source'), %w[table]).fetch('table'), %w[id schema])
          schema = object(table.fetch('schema'), %w[names value_type])
          s = Schema.new(names: schema.fetch('names'), value_type: enum(schema.fetch('value_type'), %w[int64 boolean utf8 binary]))
          s.names.each { |name| catalog_name(name) }
          raise IncompatibleNative, 'Duplicate column name' unless s.names.uniq.length == 2
          Definition.new(scope: scope(v.fetch('scope')), object: Value.wide(v.fetch('object'), min: 1),
            revision: Value.wide(v.fetch('revision'), min: 1), name: v.fetch('name'), source: TableSource.new(table: table.fetch('id'), schema: s),
            principal: v.fetch('principal'), operation: Value.wide(v.fetch('operation'), min: 1), input: v.fetch('input'))
        end
        def resolved(value, scope, name: nil, object: nil, revision: nil)
          result = definition(value)
          if result && (result.scope != scope || (name && result.name != name) || (object && result.object != object) || (revision && result.revision != revision))
            raise IncompatibleNative, 'Definition differs from requested identity'
          end
          result
        end
        def cursor(value)
          return nil if value.nil?
          v = object(value, %w[definition scope resource_revision after])
          Cursor.new(definition: v.fetch('definition'), scope: scope(v.fetch('scope')), resource_revision: v.fetch('resource_revision'), after: v.fetch('after'))
        end
        def page(value, scope, previous)
          v = object(value, %w[resource_revision entries next]); slots = v.fetch('entries')
          raise IncompatibleNative, 'Expected eight optional definition slots' unless slots.is_a?(Array) && slots.length == 8
          ended = false; entries = []
          slots.each do |slot|
            entry = definition(slot)
            if entry.nil? then ended = true
            else
              raise IncompatibleNative, 'Page has a hole or foreign scope' if ended || entry.scope != scope
              entries << entry
            end
          end
          result = Page.new(resource_revision: v.fetch('resource_revision'), entries: entries, next: cursor(v.fetch('next')))
          if previous && (result.resource_revision != previous.resource_revision || (result.entries.first && result.entries.first.name <= previous.after))
            raise IncompatibleNative, 'Response does not continue the requested page'
          end
          result
        end
      end
      private_constant :Values
      Scope = Data.define(:resource, :catalog) do
        def initialize(resource:, catalog:)
          super(resource: Values.typed(resource, ResourceRef), catalog: Internal.integer(catalog, max: U64_MAX))
        end
        def wire = { 'realm' => resource.realm, 'resource' => resource.resource, 'catalog' => catalog.to_s }
      end
      Connection = Data.define(:owner, :scope) do
        def initialize(owner:, scope:)
          Values.typed(owner, ProcessRef); Values.typed(scope, Scope)
          raise ArgumentError, 'Catalog connection requires one realm' unless owner.realm == scope.resource.realm
          super
        end
        def wire(principal) = { 'scope' => scope.wire, 'owner' => owner.pid, 'principal' => Internal.integer(principal, min: 0) }
      end
      Configuration = Data.define(:scope, :owner, :administrator) do
        def initialize(scope:, owner:, administrator:)
          Connection.new(owner: owner, scope: scope)
          super(scope: scope, owner: owner, administrator: Internal.integer(administrator))
        end
        def wire = { 'scope' => scope.wire, 'owner' => owner.pid, 'administrator' => administrator }
      end
      Schema = Data.define(:names, :value_type) do
        def initialize(names:, value_type:)
          unless names.is_a?(Array) && names.length == 2 && %i[int64 boolean utf8 binary].include?(value_type)
            raise ArgumentError, 'Catalog schema requires two names and a supported value type'
          end
          super(names: names.map { |v| Values.name(v) }.freeze, value_type: value_type)
        end
        def wire = { 'names' => names, 'value_type' => value_type.to_s }
      end
      CreateTable = Data.define(:scope, :operation, :object, :table, :name, :schema) do
        def initialize(scope:, operation:, object:, table:, name:, schema:)
          super(scope: Values.typed(scope, Scope), operation: Internal.integer(operation, max: U64_MAX),
            object: Internal.integer(object, max: U64_MAX), table: Internal.integer(table, max: (1 << 32)-1),
            name: Values.name(name), schema: Values.typed(schema, Schema))
        end
        def wire
          { 'scope' => scope.wire, 'operation' => operation.to_s, 'object' => object.to_s,
            'table' => table, 'name' => name, 'schema' => schema.wire }
        end
      end
      Compiled = Data.define(:request, :canonical) do
        def initialize(request:, canonical:)
          bytes = Internal.bytes(canonical, 256).freeze
          raise ArgumentError, 'Empty canonical catalog request' if bytes.empty?
          super(request: Values.typed(request, CreateTable), canonical: bytes)
        end
      end
      Policy = Data.define(:scope, :principal, :revision, :can_inspect, :can_create) do
        def initialize(scope:, principal:, revision:, can_inspect:, can_create:)
          super(scope: Values.typed(scope, Scope), principal: Internal.integer(principal, min: 0),
            revision: Internal.integer(revision, max: U64_MAX), can_inspect: Internal.boolean(can_inspect), can_create: Internal.boolean(can_create))
        end
        def wire
          { 'scope' => scope.wire, 'principal' => principal, 'revision' => revision.to_s, 'inspect' => can_inspect, 'create' => can_create }
        end
      end
      PolicyChange = Data.define(:expected_revision, :policy) do
        def initialize(expected_revision:, policy:)
          super(expected_revision: Internal.integer(expected_revision, min: 0, max: U64_MAX), policy: Values.typed(policy, Policy))
        end
        def wire = { 'expected_revision' => expected_revision.to_s, 'policy' => policy.wire }
      end
      Prepared = Data.define(:data) do
        def initialize(data:)
          value = Internal.text(data, 8192).freeze
          raise ArgumentError, 'Empty saved catalog command' if value.empty?
          super(data: value)
        end
        def inspect = '#<Transit::Station::Catalog::Prepared>'
      end
      class Uncertain < UnknownOutcome
        attr_reader :prepared
        def initialize(prepared, cause)
          @prepared = prepared
          super('Catalog admission is uncertain; retain the identical command', status: 6,
            code: cause.respond_to?(:code) ? cause.code : nil, phase: :submit_catalog)
        end
      end
      Capabilities = Data.define(:version, :definition, :initialize_catalog, :create_table, :conditional_policy, :current_metadata,
        :max_saved_bytes, :table_columns)
      Description = Data.define(:configuration, :policy, :resource_revision)
      TableSource = Data.define(:table, :schema) do
        def initialize(table:, schema:)
          super(table: Internal.integer(table, max: (1 << 32)-1), schema: Values.typed(schema, Schema))
        end
      end
      Definition = Data.define(:scope, :object, :revision, :name, :source, :principal, :operation, :input) do
        def initialize(scope:, object:, revision:, name:, source:, principal:, operation:, input:)
          super(scope: Values.typed(scope, Scope), object: Internal.integer(object, max: U64_MAX), revision: Internal.integer(revision, max: U64_MAX),
            name: Values.catalog_name(name), source: Values.typed(source, TableSource), principal: Internal.integer(principal, min: 0),
            operation: Internal.integer(operation, max: U64_MAX), input: Internal.integer(input))
        end
      end
      Cursor = Data.define(:definition, :scope, :resource_revision, :after) do
        def initialize(definition:, scope:, resource_revision:, after:)
          raise IncompatibleNative, 'Foreign catalog cursor definition' unless definition == Internal::CONTRACT.fetch('definition')
          super(definition: Internal.text(definition, 64).freeze, scope: Values.typed(scope, Scope),
            resource_revision: Internal.integer(resource_revision), after: Values.catalog_name(after))
        end
        def wire = { 'definition' => definition, 'scope' => scope.wire, 'resource_revision' => resource_revision, 'after' => after }
      end
      Page = Data.define(:resource_revision, :entries, :next) do
        def initialize(resource_revision:, entries:, next:)
          revision = Internal.integer(resource_revision)
          unless entries.is_a?(Array) && entries.length <= 8 && entries.all? { |entry| entry.is_a?(Definition) }
            raise ArgumentError, 'Expected at most eight definitions'
          end
          entries.each_cons(2) do |previous, entry|
            raise ArgumentError, 'Expected ordered definitions in one scope' unless previous.scope == entry.scope && previous.name < entry.name
          end
          continuation = binding.local_variable_get(:next)
          if continuation
            Values.typed(continuation, Cursor); last = entries.last
            unless last && continuation.scope == last.scope && continuation.after == last.name && continuation.resource_revision == revision
              raise ArgumentError, 'Continuation does not match the page'
            end
          end
          super(resource_revision: revision, entries: entries.dup.freeze, next: continuation)
        end
      end
      Receipt = Data.define(:request, :principal, :input, :outcome)
      Disposition = Data.define(:scope, :origin, :principal, :input, :payload, :outcome)
      class Client
        attr_reader :connection
        def self.open(config, credential, connection)
          return new(config, credential, connection) unless block_given?
          Thread.handle_interrupt(Object => :never) do
            owner = new(config, credential, connection)
            begin
              Thread.handle_interrupt(Object => :immediate) { yield owner }
            ensure
              owner.close
            end
          end
        end
        def initialize(config, credential, connection)
          unless config.is_a?(ClientConfig) && credential.is_a?(Credential) && connection.is_a?(Connection) && credential.realm == connection.scope.resource.realm
            raise ArgumentError, 'Expected configuration and credential matching the catalog realm'
          end
          @connection = connection
          target = connection.wire(credential.principal)
          @worker = Internal::Worker.new do
            bridge = Bridge.new({ 'url' => config.url, 'seed_file' => credential.seed_file,
              'catalog_client' => { 'connection' => target, 'timeout_ms' => config.timeout_ms } }, config.native_host)
            begin
              caps = Values.result(bridge.catalog({ 'capabilities' => {} }), 'capabilities')
              definition = Internal::CONTRACT.fetch('definition')
              unless caps['version'] == 1 && caps['definition'] == definition && caps['max_saved_bytes'] == 8192 && caps['table_columns'] == 2 &&
                  %w[initialize create_table conditional_policy current_metadata].all? { |name| caps[name] == true }
                raise UnsupportedCapability, 'Native catalog client lacks the named Table profile'
              end
              bridge
            rescue Exception
              bridge.close
              raise
            end
          end
        end
        def capabilities
          v = read({ 'capabilities' => {} }, 'capabilities')
          Values.object(v, %w[version definition initialize create_table conditional_policy current_metadata max_saved_bytes table_columns])
          Capabilities.new(version: Internal.integer(v.fetch('version'), max: 255), definition: Internal.text(v.fetch('definition'), 64).freeze,
            initialize_catalog: Internal.boolean(v.fetch('initialize')), create_table: Internal.boolean(v.fetch('create_table')),
            conditional_policy: Internal.boolean(v.fetch('conditional_policy')), current_metadata: Internal.boolean(v.fetch('current_metadata')),
            max_saved_bytes: Internal.integer(v.fetch('max_saved_bytes'), max: 65535), table_columns: Internal.integer(v.fetch('table_columns'), max: 255))
        end
        def describe
          v = read({ 'describe' => {} }, 'description')
          Values.object(v, %w[configuration policy resource_revision])
          Description.new(configuration: Values.configuration(v.fetch('configuration')), policy: Values.policy(v.fetch('policy')),
            resource_revision: Internal.integer(v.fetch('resource_revision'), min: 0))
        end
        def lookup(name)
          name = Values.catalog_name(name)
          value = read({ 'lookup' => name }, 'definition')
          decode_metadata { Values.resolved(value, connection.scope, name: name) }
        end
        def definition(object, revision)
          action = { 'definition' => { 'object' => Internal.integer(object, max: U64_MAX).to_s, 'revision' => Internal.integer(revision, max: U64_MAX).to_s } }
          value = read(action, 'definition')
          decode_metadata { Values.resolved(value, connection.scope, object: object, revision: revision) }
        end
        def list(cursor = nil)
          continuation = cursor && Values.typed(cursor, Cursor).wire
          value = read({ 'list' => continuation }, 'page')
          decode_metadata { Values.page(value, connection.scope, cursor) }
        end
        def compile_sql(sql, operation, object, table)
          text = Internal.text(sql, 4096)
          raise ArgumentError, 'Empty catalog SQL' if text.empty?
          action = { 'compile' => { 'sql' => text, 'operation' => Internal.integer(operation, max: U64_MAX).to_s,
            'object' => Internal.integer(object, max: U64_MAX).to_s, 'table' => Internal.integer(table, max: (1 << 32)-1) } }
          v = read(action, 'compiled'); Values.object(v, %w[request canonical])
          Compiled.new(request: Values.request(v.fetch('request')), canonical: Internal.unhex(v.fetch('canonical'), 256))
        end
        def prepare_initialize(configuration) = prepare('prepare_initialize', Values.typed(configuration, Configuration).wire)
        def prepare_create(request) = prepare('prepare_create', Values.typed(request, CreateTable).wire)
        def prepare_policy(change) = prepare('prepare_policy', Values.typed(change, PolicyChange).wire)
        def submit(prepared)
          value = call({ 'submit' => Values.typed(prepared, Prepared).data })
          begin
            receipt = Values.result(value, 'receipt'); Values.object(receipt, %w[position])
            Internal.integer(receipt.fetch('position'))
          rescue ArgumentError, TypeError, KeyError, IncompatibleNative => error
            raise Uncertain.new(prepared, error), cause: error
          end
        rescue UnknownOutcome, NoMemoryError => error
          raise if error.is_a?(Uncertain)
          raise Uncertain.new(prepared, error), cause: error
        end
        def observe(prepared, position)
          Values.enum(read(input('observe', prepared, position), 'observation'), %w[pending processed])
        end
        def input_disposition(prepared, position)
          v = read(input('input_disposition', prepared, position), 'disposition')
          return nil if v.nil?
          Values.object(v, %w[scope origin principal input payload outcome])
          payload = Internal.unhex(v.fetch('payload'), 32).freeze
          raise IncompatibleNative, 'Invalid catalog payload digest' unless payload.bytesize == 32
          Disposition.new(scope: Values.scope(v.fetch('scope')), origin: Values.enum(v.fetch('origin'), %w[external process effect]),
            principal: Internal.integer(v.fetch('principal'), min: 0), input: Internal.integer(v.fetch('input')), payload: payload,
            outcome: Values.enum(v.fetch('outcome'), %w[initialized policy_applied invalid_command denied identity_conflict stale_policy]))
        end
        def status(original)
          v = read({ 'status' => Values.typed(original, CreateTable).wire }, 'status')
          return nil if v.nil?
          Values.object(v, %w[request principal input outcome]); request = Values.request(v.fetch('request'))
          raise IncompatibleNative, 'Catalog status differs from original request' unless request == original
          Receipt.new(request: request, principal: Internal.integer(v.fetch('principal'), min: 0), input: Internal.integer(v.fetch('input')),
            outcome: Values.enum(v.fetch('outcome'), %w[applied name_conflict object_conflict table_conflict]))
        end
        def close = @worker.close
        private
        def decode_metadata
          yield
        rescue ArgumentError, TypeError, KeyError
          raise IncompatibleNative, 'Invalid catalog metadata response'
        end
        def call(action) = @worker.call { |bridge| bridge.catalog(action) }
        def read(action, tag) = Values.result(call(action), tag)
        def prepare(name, value) = Prepared.new(data: read({ name => value }, 'prepared'))
        def input(name, prepared, position)
          { name => { 'prepared' => Values.typed(prepared, Prepared).data, 'input' => Internal.integer(position) } }
        end
      end
    end
  end
end
