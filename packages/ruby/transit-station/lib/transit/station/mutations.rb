# frozen_string_literal: true
module Transit
  module Station
    # Language values and scheduling; shared Zig owns mutation and recovery semantics.
    module Mutations
      INSERT, UPDATE, DELETE = 1, 2, 4
      Connection = Data.define(:writer, :resource, :table) do
        def initialize(writer:, resource:, table:)
          unless writer.is_a?(ProcessRef) && resource.is_a?(ResourceRef) && writer.realm == resource.realm
            raise ArgumentError, 'Mutation connection requires one realm'
          end
          super(writer: writer, resource: resource, table: Internal.integer(table, max: (1 << 32)-1))
        end
        def wire(principal)
          { 'realm' => writer.realm, 'principal' => Internal.integer(principal), 'writer' => writer.pid,
            'resource' => resource.resource, 'table' => table }
        end
      end
      Reference = Data.define(:data) do
        def initialize(data:)
          value = Internal.bytes(data, 72).freeze
          raise ArgumentError, 'Mutation reference requires 72 bytes' unless value.bytesize == 72
          super(data: value)
        end
        def inspect = '#<Transit::Station::Mutations::Reference>'
      end
      Compiled = Data.define(:request, :reference) do
        def initialize(request:, reference:)
          bytes = Internal.bytes(request, 799).freeze
          raise ArgumentError, 'Invalid compiled mutation' if bytes.empty? || !reference.is_a?(Reference)
          super(request: bytes, reference: reference)
        end
        def inspect = '#<Transit::Station::Mutations::Compiled>'
      end
      Prepared = Data.define(:data) do
        def initialize(data:)
          value = Internal.text(data, 8192).freeze
          raise ArgumentError, 'Empty saved mutation command' if value.empty?
          super(data: value)
        end
        def inspect = '#<Transit::Station::Mutations::Prepared>'
      end
      class Uncertain < UnknownOutcome
        attr_reader :prepared
        def initialize(prepared, cause)
          @prepared = prepared
          super('Mutation admission is uncertain; retain the identical command', status: 6, code: cause.code, phase: :submit_mutation)
        end
      end
      Description = Data.define(:resource, :table, :names, :value_type, :resource_revision, :policy_revision,
        :declaration, :permissions, :active)
      Conflict = Data.define(:key, :row)
      Status = Data.define(:reference, :principal, :table, :declaration, :policy_revision, :phase,
        :affected_rows, :reason, :input, :conflict)
      module Values
        module_function
        def reference(value)
          raise ArgumentError, 'Expected mutation Reference' unless value.is_a?(Reference)
          value.data.unpack1('H*')
        end
        def prepared(value)
          raise ArgumentError, 'Expected saved mutation Prepared' unless value.is_a?(Prepared)
          value.data
        end
        def digest(value)
          result = Internal.unhex(value, 32).freeze
          raise IncompatibleNative, 'Invalid mutation declaration digest' unless result.bytesize == 32
          result
        end
        def revision(value) = Value.wide(value, min: 1, max: Internal::LIMITS.fetch('max_counter'))
      end
      private_constant :Values
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
          unless config.is_a?(ClientConfig) && credential.is_a?(Credential) && connection.is_a?(Connection) && credential.realm == connection.writer.realm
            raise ArgumentError, 'Expected configuration and credential matching the mutation realm'
          end
          target = connection.wire(credential.principal)
          @connection = connection
          @worker = Internal::Worker.new do
            bridge = Bridge.new({ 'url' => config.url, 'seed_file' => credential.seed_file,
              'mutation_client' => { 'connection' => target, 'timeout_ms' => config.timeout_ms } }, config.native_host)
            begin
              caps = bridge.table_mutation({ 'capabilities' => {} }).fetch('capabilities')
              unless caps['version'] == 1 && caps['max_rows'] == 3 && caps['max_request_bytes'] == 799 && caps['max_saved_bytes'] == 8192 &&
                  %w[insert update_primary_key delete_primary_key].all? { |name| caps[name] }
                raise UnsupportedCapability, 'Native mutation client lacks the bounded Table profile'
              end
              bridge
            rescue Exception
              bridge.close
              raise
            end
          end
        end
        def describe
          v = call({ 'describe' => {} }).fetch('description')
          unless v.fetch('resource') == connection.resource.resource && v.fetch('table') == connection.table
            raise IncompatibleNative, 'Mutation description differs from the configured target'
          end
          Description.new(resource: connection.resource, table: connection.table,
            names: v.fetch('names').map { |name| Internal.text(name, 16).freeze }.freeze, value_type: v.fetch('value_type').to_sym,
            resource_revision: Internal.integer(v.fetch('resource_revision'), min: 0), policy_revision: Values.revision(v.fetch('policy_revision')),
            declaration: Values.digest(v.fetch('declaration')), permissions: Internal.integer(v.fetch('permissions'), min: 0, max: 7),
            active: v.fetch('active').nil? ? nil : Value.wide(v.fetch('active'), min: 1))
        end
        def compile_sql(name, sql, namespace)
          result = call({ 'compile' => { 'name' => Internal.text(name, 16), 'sql' => Internal.text(sql, 4096),
            'namespace' => Internal.integer(namespace, max: U64_MAX).to_s } }).fetch('compiled')
          Compiled.new(request: Internal.unhex(result.fetch('request'), 799), reference: Reference.new(data: Internal.unhex(result.fetch('reference'), 72)))
        end
        def prepare_next(compiled)
          raise ArgumentError, 'Expected compiled mutation' unless compiled.is_a?(Compiled)
          value = call({ 'next' => { 'request' => compiled.request.unpack1('H*'), 'reference' => Values.reference(compiled.reference) } }).fetch('prepared')
          value.nil? ? nil : Prepared.new(data: value)
        end
        def prepare_apply(reference) = control('apply', reference)
        def prepare_cancel(reference) = control('cancel', reference)
        def submit(prepared)
          token = Values.prepared(prepared)
          value = call({ 'submit' => token })
          receipt = value['receipt']
          raise UnknownOutcome, 'Missing mutation admission receipt' unless receipt && receipt.fetch('position') > 0
          Internal.integer(receipt.fetch('position'))
        rescue UnknownOutcome => error
          raise Uncertain.new(prepared, error), cause: error
        end
        def observe(prepared, position)
          call(input('observe', prepared, position)).fetch('observation').to_sym
        end
        def rejection(prepared, position)
          call(input('rejection', prepared, position)).fetch('rejection')&.to_sym
        end
        def status(reference)
          encoded = Values.reference(reference)
          v = call({ 'status' => encoded }).fetch('status')
          return nil if v.nil?
          unless v.fetch('reference') == encoded && v.fetch('table') == connection.table
            raise IncompatibleNative, 'Status differs from the mutation reference'
          end
          Status.new(reference: Reference.new(data: Internal.unhex(v.fetch('reference'), 72)), principal: Internal.integer(v.fetch('principal')),
            table: connection.table, declaration: Values.digest(v.fetch('declaration')), policy_revision: Values.revision(v.fetch('policy_revision')),
            phase: v.fetch('phase').to_sym, affected_rows: Internal.integer(v.fetch('affected_rows'), min: 0, max: 3),
            reason: v.fetch('reason').to_sym, input: Internal.integer(v.fetch('input'), min: 0),
            conflict: v.fetch('conflict').then { |c| c.nil? ? nil : Conflict.new(
              key: Internal.integer(Integer(c.fetch('key'), 10), min: -(1 << 63), max: (1 << 63)-1),
              row: Internal.integer(c.fetch('row'), min: 1, max: 3)) })
        end
        def close = @worker.close
        private
        def call(action) = @worker.call { |bridge| bridge.table_mutation(action) }
        def control(name, reference)
          value = call({ 'prepare' => { name => Values.reference(reference) } }).fetch('prepared')
          raise IncompatibleNative, 'Missing prepared mutation control' if value.nil?
          Prepared.new(data: value)
        end
        def input(name, prepared, position)
          { name => { 'prepared' => Values.prepared(prepared), 'input' => Internal.integer(position) } }
        end
      end
    end
  end
end
