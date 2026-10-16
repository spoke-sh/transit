# frozen_string_literal: true
require_relative 'catalog_values'
module Transit
  module Station
    # Owned values and scheduling; Zig owns compilation, authority and recovery.
    module Catalog
      class Uncertain < UnknownOutcome
        attr_reader :prepared
        def initialize(prepared, cause)
          @prepared = prepared
          super('Table admission is uncertain; retain the identical prepared command', status: 6,
            code: cause.respond_to?(:code) ? cause.code : nil, phase: :submit_catalog,
            diagnostic: cause.respond_to?(:diagnostic) ? cause.diagnostic : nil,
            diagnostic_invalid: cause.respond_to?(:diagnostic_invalid) && cause.diagnostic_invalid)
        end
      end
      class Client
        attr_reader :connection
        def self.open(config, credential, connection, table_service_url: nil)
          return new(config, credential, connection, table_service_url: table_service_url) unless block_given?
          Thread.handle_interrupt(Object => :never) do
            owner = new(config, credential, connection, table_service_url: table_service_url)
            begin
              Thread.handle_interrupt(Object => :immediate) { yield owner }
            ensure
              owner.close
            end
          end
        end
        def initialize(config, credential, connection, table_service_url: nil)
          unless config.is_a?(ClientConfig) && credential.is_a?(Credential) && connection.is_a?(Connection) && credential.realm == connection.scope.resource.realm
            raise ArgumentError, 'Expected configuration and credential matching the catalog realm'
          end
          @connection, @principal = connection, credential.principal
          target = connection.wire(@principal)
          service_url = table_service_url.nil? ? nil : ClientConfig.new(url: Values.text(table_service_url, 2048), profile: :native_v1).url
          @worker = Internal::Worker.new do
            bridge = Bridge.new({ 'url' => config.url, 'seed_file' => credential.seed_file,
              'catalog_client' => { 'connection' => target, 'timeout_ms' => config.timeout_ms, 'table_service_url' => service_url } }, config.native_host)
            begin
              caps = decode { Values.capabilities(Values.result(bridge.catalog({ 'capabilities' => {} }), 'capabilities')) }
              raise UnsupportedCapability, 'Native catalog client lacks general Tables' unless Values.supported?(caps)
              bridge
            rescue Exception
              bridge.close
              raise
            end
          end
        end
        def capabilities = read({ 'capabilities' => {} }, 'capabilities') { |v| Values.capabilities(v) }
        def describe = read({ 'describe' => {} }, 'description') { |v| Values.description(v, connection, @principal) }
        def lookup(name)
          name = Values.name(name)
          read({ 'lookup' => name }, 'definition') { |v| Values.resolved(v, connection.scope, connection.namespace, name) }
        end
        def definition(object, revision)
          action = { 'definition' => { 'object' => Values.wide(object).to_s, 'revision' => Values.wide(revision).to_s } }
          read(action, 'historical') { |v| Values.historical(v, connection.scope, object, revision) }
        end
        def list(cursor = nil)
          if cursor
            Values.typed(cursor, Cursor)
            raise ArgumentError, 'Foreign catalog cursor' unless cursor.scope == connection.scope
          end
          read({ 'list' => cursor&.wire }, 'page') do |v|
            page = Values.page(v, connection.scope, cursor)
            raise IncompatibleNative, 'Foreign schema namespace' unless page.entries.all? { |entry| entry.metadata.namespace == connection.namespace }
            page
          end
        end
        def compile_sql(sql, identity, create_object = nil)
          Values.typed(identity, Identity)
          action = { 'compile' => { 'sql' => Values.text(sql, 4096), 'identity' => identity.wire,
            'create_object' => create_object.nil? ? nil : Values.wide(create_object).to_s } }
          read(action, 'compiled') { |v| Values.compiled(v, connection, @principal, identity, create_object.nil? ? nil : :create, create_object) }
        end
        def prepare(name, identity, operation)
          Values.typed(identity, Identity)
          raise ArgumentError, 'Expected typed Table operation' unless [Create, Alter, Rename, Drop, Mutate].any? { |type| operation.is_a?(type) }
          action = { 'prepare' => { 'definition' => DEFINITION, 'identity' => identity.wire, 'name' => Values.name(name), 'action' => operation.wire } }
          read(action, 'compiled') { |v| Values.compiled(v, connection, @principal, identity, operation.kind, operation.object) }
        end
        def load(saved)
          read({ 'load' => Values.typed(saved, SavedIntent).wire }, 'loaded') { |v| Values.intent(v, connection, @principal) }
        end
        def forget(intent)
          read({ 'forget' => reference(intent) }, 'forgotten') { |v| Values.object(v, []); nil }
        end
        def next(intent) = read({ 'next' => reference(intent) }, 'next') { |v| Values.next_step(v) }
        def status(intent) = read({ 'status' => reference(intent) }, 'state') { |v| Values.state(v) }
        def prepare_resume(intent) = prepared('prepare_resume', reference(intent))
        def prepare_control(intent, control)
          prepared('prepare_control', { 'intent' => reference(intent), 'control' => Values.symbol(control, %i[cancel_operation cleanup_operation cancel_upload collect_upload]) })
        end
        def prepare_initialize(configuration) = prepared('prepare_initialize', Values.typed(configuration, Configuration).wire)
        def prepare_dependency(dependency, present) = prepared('prepare_dependency', Values.typed(dependency, Dependency).wire(present))
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
        def observe(prepared, position, wait: false)
          read({ (Internal.boolean(wait) ? 'wait_observe' : 'observe') => input(prepared, position) }, 'observation') { |v| Values.enum(v, %i[pending processed]) }
        end
        def input_disposition(prepared, position)
          read({ 'input_disposition' => input(prepared, position) }, 'disposition') { |v| Values.disposition(v) }
        end
        def progress(intent, prepared, position, wait: false)
          action = { (Internal.boolean(wait) ? 'wait_progress' : 'progress') => { 'intent' => reference(intent) }.merge(input(prepared, position)) }
          read(action, 'progress') { |v| Values.progress(v) }
        end
        def close = @worker.close
        private
        def decode
          yield
        rescue ArgumentError, TypeError, KeyError
          raise IncompatibleNative, 'Invalid catalog response'
        end
        def call(action)
          # Encode before handing ownership to a worker that can outlive its waiter.
          data = JSON.generate(action)
          raise ArgumentError, 'Table action exceeds its bound' if data.bytesize > LIMITS.fetch('catalog_action_bytes')
          @worker.call { |bridge| bridge.catalog(JSON.parse(data)) }
        end
        def read(action, tag)
          value = call(action)
          decode { yield Values.result(value, tag) }
        end
        def prepared(name, value) = read({ name => value }, 'prepared') { |v| Prepared.new(data: v) }
        def reference(intent) = Values.typed(intent, Reference).wire
        def input(prepared, position)
          { 'prepared' => Values.typed(prepared, Prepared).data, 'input' => Internal.integer(position) }
        end
      end
    end
  end
end
