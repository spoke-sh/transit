# frozen_string_literal: true
require_relative 'catalog_values'
module Transit
  module Station
    TableSchema = Catalog::Schema
    RowIdentity = Data.define(:bytes) do
      def initialize(bytes:)
        value = Internal.bytes(bytes, 20).freeze
        raise ArgumentError, 'Expected 20-byte row identity' unless value.bytesize == 20
        super(bytes: value)
      end
    end
    Row = Data.define(:identity, :cells) do
      def initialize(identity:, cells:)
        raise ArgumentError, 'Expected row identity and cells' unless identity.is_a?(RowIdentity) && cells.is_a?(Array) && cells.length.between?(1, 128)
        super(identity: identity, cells: cells.map { |cell| Logical.cell(cell) }.freeze)
      end
      def inspect = '#<Transit::Station::Row>'
    end
    TableBasis = Data.define(:resource, :revision, :object, :head)
    TablePage = Data.define(:rows, :cursor)
    TableCreation = Data.define(:state, :admitted_input, :completed_input)
    TableWitness = Data.define(:source, :row, :column, :text, :truncated)
    TableMutationStatus = Data.define(:reference, :state, :route, :admitted_input, :completed_input, :counts, :rejection, :witness)

    module TableValues
      SCHEMA = JSON.parse(File.binread(File.join(__dir__, 'schemas.json'))).fetch('GrowingAction').freeze
      CODEC = Catalog.const_get(:Values)
      private_constant :SCHEMA, :CODEC
      module_function
      def schema(value) = CODEC.schema(value)
      def saved(data, tag)
        bytes = Internal.bytes(data, Catalog::LIMITS.fetch('handler_action_bytes'))
        value = JSON.parse(bytes, max_nesting: 96)
        raise IncompatibleNative, 'Noncanonical Table intent' unless JSON.generate(value) == bytes
        envelope = { 'table' => { tag => value } }
        Internal.bytes(JSON.generate(envelope), Catalog::LIMITS.fetch('handler_action_bytes'))
        Internal.validate!(SCHEMA, envelope)
        value
      end
      def hex(value, size)
        bytes = Internal.unhex(value, size)
        raise IncompatibleNative, 'Invalid canonical Table bytes' unless bytes.bytesize == size && bytes.unpack1('H*') == value
        bytes.freeze
      end
      def same_resource(turn, value)
        unless turn.resource == ResourceRef.new(realm: value.fetch('realm'), resource: value.fetch('resource'))
          raise HandlerError, 'Table intent belongs to another realm or resource'
        end
      end
      def action(turn, tag, value, result, read: false)
        turn.__send__(:operation, read: read) do
          raw = turn.__send__(:raw_native, { 'table' => { tag => value } })
          value = Logical.object(Logical.object(raw, %w[table]).fetch('table'), [result]).fetch(result)
          block_given? ? yield(value) : value
        end
      end
      def status(value)
        v = Logical.object(value, %w[reference state route admitted_input completed_input counts rejection witness])
        state = CODEC.enum(v.fetch('state'), %i[building applied rejected cancelled])
        route = CODEC.enum(v.fetch('route'), %i[point statement alter])
        rejection = CODEC.enum(v.fetch('rejection'), %i[none row_exists row_identity_exists null_not_allowed missing_required_field character_limit_exceeded overflow inexact])
        admitted = Internal.integer(v.fetch('admitted_input'))
        completed = v.fetch('completed_input')&.then { |n| Internal.integer(n) }
        unless (completed.nil? == (state == :building)) && (completed.nil? || completed >= admitted) && ((rejection != :none) == (state == :rejected))
          raise IncompatibleNative, 'Invalid Table mutation completion'
        end
        counts = v.fetch('counts')&.then do |c|
          Logical.object(c, %w[matched changed])
          Catalog::Counts.new(matched: Value.wide(c.fetch('matched')), changed: Value.wide(c.fetch('changed')))
        end
        raise IncompatibleNative, 'Counts require an applied mutation' unless !counts.nil? == (state == :applied)
        witness = v.fetch('witness')&.then do |w|
          Logical.object(w, %w[source row column text truncated])
          TableWitness.new(source: CODEC.enum(w.fetch('source'), %i[input stored withheld]),
            row: w.fetch('row')&.then { |r| RowIdentity.new(bytes: hex(r, 20)) }, column: Value.wide(w.fetch('column')),
            text: Internal.text(w.fetch('text'), 256).freeze, truncated: Internal.boolean(w.fetch('truncated')))
        end
        TableMutationStatus.new(reference: TableMutationReference.load(JSON.generate(v.fetch('reference'))),
          state: state, route: route, admitted_input: admitted, completed_input: completed, counts: counts, rejection: rejection, witness: witness)
      end
      def row(value)
        v = Logical.object(value, %w[identity cells])
        raise IncompatibleNative, 'Invalid row width' unless v.fetch('cells').is_a?(Array) && v.fetch('cells').length.between?(1, 128)
        Row.new(identity: RowIdentity.new(bytes: hex(v.fetch('identity'), 20)), cells: v.fetch('cells').map { |cell| Logical.cell_from_wire(cell) })
      end
    end
    private_constant :TableValues

    class TableMutationReference
      def initialize(data)
        v = TableValues.saved(data, 'status')
        raise IncompatibleNative, 'Foreign Table definition' unless v.fetch('definition') == Catalog::DEFINITION
        ResourceRef.new(realm: v.fetch('realm'), resource: v.fetch('resource'))
        Value.wide(v.fetch('object'), min: 1); Value.wide(v.fetch('operation'), min: 1)
        TableValues.hex(v.fetch('digest'), 32)
        @data = data.dup.freeze
        freeze
      end
      def self.load(data) = new(data)
      def save = @data
      def status(turn) = read(turn, 'status')
      def cancel(turn)
        read(turn, 'cancel') || raise(IncompatibleNative, 'Missing cancelled mutation')
      end
      def inspect = '#<Transit::Station::TableMutationReference>'
      private
      def read(turn, tag)
        value = JSON.parse(@data)
        TableValues.same_resource(turn, value)
        TableValues.action(turn, tag, value, 'mutation', read: tag == 'status') do |raw|
          next nil if raw.nil?
          result = TableValues.status(raw)
          raise IncompatibleNative, 'Foreign Table mutation outcome' unless JSON.parse(result.reference.save) == value
          result
        end
      end
    end

    class TableMutation
      def initialize(data)
        value = TableValues.saved(data, 'mutate')
        TableValues.schema(value.fetch('schema'))
        ResourceRef.new(realm: value.fetch('realm'), resource: value.fetch('resource'))
        Value.wide(value.fetch('operation'), min: 1)
        @data = data.dup.freeze
        freeze
      end
      def self.load(data) = new(data)
      def self.prepare(resource:, principal:, operation:, schema:, mutation:)
        unless resource.is_a?(ResourceRef) && schema.is_a?(TableSchema) && [Catalog::Insert, Catalog::Update, Catalog::Delete].any? { |kind| mutation.is_a?(kind) }
          raise ArgumentError, 'Expected a resource, general schema and typed mutation'
        end
        new(JSON.generate({ 'realm' => resource.realm, 'resource' => resource.resource, 'principal' => Internal.integer(principal, min: 0),
          'operation' => Internal.integer(operation, max: U64_MAX).to_s, 'schema' => schema.wire, 'mutation' => mutation.wire }))
      end
      def save = @data
      def schema = TableValues.schema(JSON.parse(@data).fetch('schema'))
      def operation = Value.wide(JSON.parse(@data).fetch('operation'), min: 1)
      def step(turn)
        value = JSON.parse(@data)
        TableValues.same_resource(turn, value)
        result = TableValues.status(TableValues.action(turn, 'mutate', value, 'mutation'))
        identity = JSON.parse(result.reference.save)
        unless %w[realm resource principal operation].all? { |key| identity.fetch(key) == value.fetch(key) } && identity.fetch('object') == value.fetch('schema').fetch('object')
          raise IncompatibleNative, 'Foreign Table mutation outcome'
        end
        result
      end
      def inspect = '#<Transit::Station::TableMutation>'
    end

    class Table
      attr_reader :schema, :basis
      def initialize(turn, object, version = nil)
        @turn, @object, @version = turn, Internal.integer(object, max: U64_MAX), version
        TableValues.action(turn, 'schema', source, 'schema', read: true) do |value|
          metadata = Logical.object(value, %w[schema basis])
          @schema = TableValues.schema(metadata.fetch('schema'))
          b = Logical.object(metadata.fetch('basis'), %w[resource revision object head])
          @basis = TableBasis.new(resource: ResourceRef.new(realm: turn.process.realm, resource: b.fetch('resource')),
            revision: Internal.integer(b.fetch('revision')), object: Value.wide(b.fetch('object'), min: 1), head: TableValues.hex(b.fetch('head'), 32))
          raise IncompatibleNative, 'Foreign Table definition' unless basis.object == @object && schema.object == @object
        end
        freeze
      end
      def self.create(turn, schema, limits)
        raise ArgumentError, 'Expected schema and limits' unless schema.is_a?(TableSchema) && limits.is_a?(Catalog::TableLimits)
        value = TableValues.action(turn, 'create', { 'realm' => turn.resource.realm, 'resource' => turn.resource.resource,
          'schema' => schema.wire, 'limits' => limits.wire }, 'created')
        Logical.object(value, %w[state admitted_input completed_input])
        state = value.fetch('state')
        admitted = Internal.integer(value.fetch('admitted_input')); completed = Internal.integer(value.fetch('completed_input'), min: 0)
        unless %w[building applied].include?(state) && ((completed == 0) == (state == 'building')) && (completed == 0 || completed >= admitted)
          raise IncompatibleNative, 'Invalid Table creation completion'
        end
        TableCreation.new(state: state.to_sym, admitted_input: admitted, completed_input: completed == 0 ? nil : completed)
      end
      def get(identity)
        raise ArgumentError, 'Expected row identity' unless identity.is_a?(RowIdentity)
        read_row('get', { 'source' => source, 'identity' => identity.bytes.unpack1('H*') })
      end
      def get_key(key)
        raise ArgumentError, 'Expected bounded primary key' unless key.is_a?(Array) && key.length.between?(1, 128)
        read_row('get_key', { 'source' => source, 'key' => key.map { |cell| Logical.cell_wire(cell) } })
      end
      def page(cursor = nil, limit: 8)
        Internal.text(cursor, 2048) unless cursor.nil?
        Internal.integer(limit, max: 8)
        TableValues.action(@turn, 'page', { 'source' => source, 'cursor' => cursor, 'limit' => limit }, 'page', read: true) do |result|
          Logical.object(result, %w[definition rows next]); check_basis(result.fetch('definition'))
          rows = result.fetch('rows')
          raise IncompatibleNative, 'Oversized Table page' unless rows.is_a?(Array) && rows.length <= limit
          TablePage.new(rows: rows.map { |row| TableValues.row(row) }.freeze, cursor: result.fetch('next')&.then { |v| Internal.text(v, 2048).freeze })
        end
      end
      def prepare(principal:, operation:, mutation:)
        @turn.__send__(:check!)
        raise HandlerError, 'Retained Tables are read-only' unless @version.nil?
        TableMutation.prepare(resource: basis.resource, principal: principal, operation: operation, schema: schema, mutation: mutation)
      end
      private
      def source = { 'object' => @object.to_s, 'version' => @version.nil? ? nil : Value.version_wire(@version) }
      def check_basis(value)
        metadata = Logical.object(value, %w[schema basis]); b = Logical.object(metadata.fetch('basis'), %w[resource revision object head])
        unless [b.fetch('resource'), b.fetch('revision'), Value.wide(b.fetch('object')), TableValues.hex(b.fetch('head'), 32)] == [basis.resource.resource, basis.revision, basis.object, basis.head]
          raise IncompatibleNative, 'Table read changed its captured basis'
        end
      end
      def read_row(tag, value)
        TableValues.action(@turn, tag, value, 'row', read: true) do |raw|
          result = Logical.object(raw, %w[definition row])
          check_basis(result.fetch('definition'))
          result.fetch('row')&.then { |row| TableValues.row(row) }
        end
      end
    end
  end
end
