# frozen_string_literal: true
require_relative 'catalog_values'
module Transit
  module Station
    # Owned language values and scheduling; Zig owns publication and recovery.
    module Catalog
      class Uncertain < UnknownOutcome
        attr_reader :original
        def initialize(original, cause)
          @original = original
          super('Catalog outcome is uncertain; retain the identical saved work or reference', status: 6,
            code: cause.respond_to?(:code) ? cause.code : nil, phase: :catalog,
            diagnostic: cause.respond_to?(:diagnostic) ? cause.diagnostic : nil,
            diagnostic_invalid: cause.respond_to?(:diagnostic_invalid) && cause.diagnostic_invalid)
        end
      end
      class Client
        attr_reader :connection
        def self.open(config, credential, connection, service_url: nil)
          return new(config, credential, connection, service_url: service_url) unless block_given?
          Thread.handle_interrupt(Object => :never) do
            owner = new(config, credential, connection, service_url: service_url)
            begin
              Thread.handle_interrupt(Object => :immediate) { yield owner }
            ensure
              owner.close
            end
          end
        end
        def initialize(config, credential, connection, service_url: nil)
          unless config.is_a?(ClientConfig) && credential.is_a?(Credential) && connection.is_a?(Connection) && credential.realm == connection.scope.resource.realm
            raise ArgumentError, 'Expected configuration and credential matching the catalog realm'
          end
          @connection, @principal = connection, credential.principal
          target = connection.wire(@principal)
          url = service_url.nil? ? nil : ClientConfig.new(url: Values.text(service_url, 2048), profile: :native_v1).url
          @worker = Internal::Worker.new do
            bridge = Bridge.new({ 'url' => config.url, 'seed_file' => credential.seed_file,
              'catalog_client' => { 'definition' => DEFINITION, 'connection' => target, 'timeout_ms' => config.timeout_ms, 'service_url' => url } }, config.native_host)
            begin
              decode do
                response = bridge.catalog({ 'catalog' => { 'capabilities' => {} } })
                Values.validate('CatalogResult', response)
                Values.capabilities(response.fetch('catalog').fetch('capabilities'))
              end
              bridge
            rescue Exception
              bridge.close
              raise
            end
          end
        end
        def capabilities = read({ 'catalog' => { 'capabilities' => {} } }, %w[catalog capabilities]) { |v| Values.capabilities(v) }
        def describe = read({ 'catalog' => { 'describe' => {} } }, %w[catalog description]) { |v| Values.description(v, connection, @principal) }
        def namespace(id)
          id = Internal.integer(id)
          read({ 'catalog' => { 'namespace' => id } }, %w[catalog namespace]) do |v|
            result = Values.namespace(v)
            raise IncompatibleNative, 'Changed namespace' if result && (result.id != id || result.scope != connection.scope)
            result
          end
        end
        def namespaces(cursor = nil) = list_page({ 'namespaces' => {} }, cursor)
        def tables(namespace: 1, cursor: nil) = list_page({ 'tables' => Internal.integer(namespace) }, cursor)
        def lookup(name, namespace: 1)
          name = Values.name(name); namespace = Internal.integer(namespace)
          read({ 'lookup' => { 'namespace' => namespace, 'name' => name } }, ['metadata']) { |v| Values.metadata(v, connection, @principal, namespace, name) }
        end
        def compile_sql(sql, identity, create_object = nil, dialect: :transit, ingestion: :point)
          Values.typed(identity, Identity)
          action = { 'compile' => { 'sql' => Values.text(sql, 4096), 'namespace' => identity.namespace, 'operation' => identity.operation.to_s,
            'create_object' => create_object.nil? ? nil : Values.wide(create_object).to_s,
            'dialect' => Values.symbol(dialect, %i[transit mysql]), 'ingestion' => Values.symbol(ingestion, %i[point bulk]) } }
          compiled(action, identity)
        end
        def prepare(name, identity, operation)
          Values.typed(identity, Identity)
          raise ArgumentError, 'Expected typed Table operation' unless [Create, Alter, Rename, Drop, Mutate].any? { |type| operation.is_a?(type) }
          action = { 'prepare' => { 'definition' => DEFINITION, 'namespace' => identity.namespace, 'operation' => identity.operation.to_s,
            'name' => Values.name(name), 'action' => operation.wire } }
          compiled(action, identity)
        end
        def load(saved)
          Values.typed(saved, SavedIntent)
          read({ 'load' => saved.wire }, ['loaded']) { |v| Values.summary(v, saved, connection, @principal) }
        end
        def forget(intent) = read({ 'forget' => Values.typed(intent, Intent).id }, ['forgotten']) { nil }
        def preview(intent) = read({ 'preview' => Values.typed(intent, Intent).id }, ['preview']) { |v| Values.preview(v, intent) }
        def stage(intent)
          Values.typed(intent, Intent)
          read({ 'stage' => intent.id }, ['staged'], original: intent.saved) do |v|
            reference = Reference.restore(JSON.generate(v))
            check_owner(reference)
            raise IncompatibleNative, 'Changed staged work' unless reference.kind == intent.kind && reference.binding == intent.binding && v.values.first.fetch('namespace') == intent.namespace
            reference
          end
        end
        def admit(reference)
          check_reference(reference)
          read({ 'admit' => reference.wire }, ['observation'], original: reference) { |v| Values.observation(v, reference) }
        end
        def inspect(reference) = operation(reference, :inspect, 1)
        def execute(reference, steps: 256) = operation(reference, :execute, Internal.integer(steps, max: 65535))
        def cancel(reference) = operation(reference, :cancel, 1)
        def prepare_snapshot(basis, position, operation)
          Values.typed(basis, Basis); Values.typed(position, Position); check_owner(basis)
          SnapshotAcquisition.restore(JSON.generate({ 'owner' => { 'definition' => DEFINITION, 'connection' => connection.wire(@principal),
            'object' => basis.interpretation.interpretation.object.wire, 'operation' => Values.wide(operation).to_s }, 'expected' => position.wire }))
        end
        def acquire_snapshot(acquisition)
          Values.typed(acquisition, SnapshotAcquisition); check_owner(acquisition.owner)
          read({ 'retention' => { 'acquire' => acquisition.wire } }, %w[retention acquired], original: acquisition) do |v|
            snapshot = Snapshot.restore(JSON.generate(v))
            raise IncompatibleNative, 'Changed retention owner' unless snapshot.owner == acquisition.owner
            snapshot
          end
        end
        def snapshot_status(owner)
          Values.typed(owner, SnapshotOwner); check_owner(owner)
          read({ 'retention' => { 'status' => owner.wire } }, %w[retention status]) do |v|
            raise IncompatibleNative, 'Changed retention owner' unless v.fetch('owner') == owner.wire
            current = Values.interpretation(v.fetch('current_interpretation'))
            raise IncompatibleNative, 'Changed retention object' unless current.object == owner.object
            snapshot = Values.optional(v.fetch('snapshot')) { |s| Snapshot.restore(JSON.generate(s)) }
            raise IncompatibleNative, 'Changed original snapshot' if snapshot && snapshot.owner != owner
            SnapshotStatus.new(owner: owner, current_interpretation: current, current_position: Values.position(v.fetch('current_position')),
              retired: v.fetch('retired'), snapshot: snapshot, released: v.fetch('released'), authority: Values.read_authority(v.fetch('authority')))
          end
        end
        def snapshot_metadata(snapshot)
          Values.typed(snapshot, Snapshot); check_owner(snapshot.owner)
          read({ 'retention' => { 'metadata' => snapshot.wire } }, %w[retention metadata]) do |v|
            raise IncompatibleNative, 'Changed snapshot content' unless v.fetch('snapshot') == snapshot.wire
            stored = Values.stored(v.fetch('interpretation')); schema = Values.schema(v.fetch('schema'))
            raise IncompatibleNative, 'Changed retained interpretation' unless stored.interpretation.object == snapshot.owner.object && schema.object == snapshot.owner.object.object
            SnapshotMetadata.new(snapshot: snapshot, interpretation: stored, accepted: Values.position(v.fetch('accepted')), changed_lsn: Values.decimal(v.fetch('changed_lsn'), min: 0),
              row_count: Values.decimal(v.fetch('row_count'), min: 0), schema: schema, authority: Values.read_authority(v.fetch('authority')))
          end
        end
        def release_snapshot(snapshot)
          Values.typed(snapshot, Snapshot); check_owner(snapshot.owner)
          read({ 'retention' => { 'release' => snapshot.wire } }, %w[retention released], original: snapshot) do |v|
            raise IncompatibleNative, 'Changed released snapshot' unless v == snapshot.wire
            snapshot
          end
        end
        def close = @worker.close
        private
        def check_owner(value)
          raise ArgumentError, 'Foreign catalog connection' unless value.connection == connection && value.principal == @principal
        end
        def check_reference(value)
          Values.typed(value, Reference); check_owner(value)
        end
        def operation(reference, command, steps)
          check_reference(reference)
          read({ 'operation' => { 'reference' => reference.wire, 'command' => command.to_s, 'steps' => steps } }, ['observation'],
            original: command == :inspect ? nil : reference) { |v| Values.observation(v, reference) }
        end
        def compiled(action, identity)
          read(action, ['compiled']) do |v|
            saved = SavedIntent.restore(JSON.generate(v.fetch('saved')))
            Compiled.new(intent: Values.summary(v.fetch('summary'), saved, connection, @principal, identity), saved: saved)
          end
        end
        def list_page(selection, cursor)
          if cursor
            Values.typed(cursor, Cursor); cursor.check(connection, @principal, selection)
          end
          action = selection.key?('namespaces') ? { 'namespaces' => cursor&.wire } : { 'tables' => { 'namespace' => selection.fetch('tables'), 'cursor' => cursor&.wire } }
          read({ 'catalog' => action }, ['catalog', selection.keys.first]) { |v| Values.page(v, connection, @principal, selection, cursor) }
        end
        def decode
          yield
        rescue ArgumentError, TypeError, KeyError
          raise IncompatibleNative, 'Invalid catalog response'
        end
        def read(action, path, original: nil)
          # Validate and encode before scheduling; caller-owned objects cannot
          # mutate a request after the worker accepts it.
          Values.action(action)
          data = JSON.generate(action)
          raise ArgumentError, 'Catalog action exceeds its bound' if data.bytesize > LIMITS.fetch('catalog_action_bytes')
          begin
            response = @worker.call { |bridge| bridge.catalog(JSON.parse(data)) }
          rescue UnknownOutcome, NoMemoryError => error
            raise unless original
            raise Uncertain.new(original, error), cause: error
          end
          begin
            decode do
              Values.validate('CatalogResult', response)
              value = path.reduce(response) { |v, key| Values.result(v, key) }
              yield value
            end
          rescue IncompatibleNative, NoMemoryError => error
            raise unless original
            raise Uncertain.new(original, error), cause: error
          end
        end
      end
    end
  end
end
