# frozen_string_literal: true
module Transit
  module Station
    module Catalog
      CONTRACT = JSON.parse(File.binread(File.join(__dir__, 'contract.json'))).freeze
      DEFINITION = CONTRACT.fetch('definition').freeze
      LIMITS = CONTRACT.fetch('limits').freeze
      KINDS = %i[create alter rename drop insert update delete].freeze
      PHASES = %i[preparing delegated building applied unchanged rejected cancelled].freeze
      module Values
        class WireBudget
          def initialize(limit) = @remaining = limit
          def take(value)
            @remaining -= JSON.generate(value).bytesize
            raise ArgumentError, 'Table wire budget exceeded' if @remaining.negative?
            value
          end
        end
        module_function
        def typed(value, type) = Logical.typed(value, type)
        def wide(value, min: 1) = Internal.integer(value, min: min, max: U64_MAX)
        def text(value, bound)
          result = Internal.text(value, bound).freeze
          raise ArgumentError, 'Expected nonempty text' if result.empty?
          result
        end
        def name(value)
          result = text(value, 255)
          raise ArgumentError, 'NUL in catalog name' if result.include?("\0")
          result
        end
        def definition(value)
          raise ArgumentError, 'Missing or foreign Table definition' unless value == DEFINITION
          DEFINITION
        end
        def object(value, fields) = Logical.object(value, fields)
        def result(value, tag) = object(value, [tag]).fetch(tag)
        def enum(value, names)
          raise IncompatibleNative, 'Unknown catalog variant' unless value.is_a?(String) && names.map(&:to_s).include?(value)
          value.to_sym
        end
        def symbol(value, names)
          raise ArgumentError, 'Unknown catalog variant' unless names.include?(value)
          value.to_s
        end
        def decimal(value, min: 1)
          raise IncompatibleNative, 'Expected bounded decimal string' unless value.is_a?(String) && value.bytesize <= 20
          Value.wide(value, min: min)
        end
        def digest(value)
          result = Internal.bytes(value, 32).freeze
          raise ArgumentError, 'Expected 32-byte digest' unless result.bytesize == 32
          result
        end
        def optional(value)
          value.nil? ? nil : yield(value)
        end
        def scope(value)
          v = object(value, %w[realm resource catalog]); Scope.new(resource: ResourceRef.new(realm: v.fetch('realm'), resource: v.fetch('resource')), catalog: decimal(v.fetch('catalog')))
        end
        def column(name, type, nullable, default, max_characters)
          { 'name' => self.name(name), 'type' => Logical.type_wire(type), 'nullable' => Internal.boolean(nullable), 'default' => default.nil? ? nil : Logical.cell_wire(default), 'max_characters' => optional(max_characters) { |v| Internal.integer(v, max: (1 << 32)-1) } }
        end
      end
      private_constant :CONTRACT, :Values
      Scope = Data.define(:resource, :catalog) do
        def initialize(resource:, catalog:) = super(resource: Values.typed(resource, ResourceRef), catalog: Values.wide(catalog))
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
      TableLimits = Data.define(:record_bytes, :staging_bytes, :staging_records) do
        def initialize(record_bytes:, staging_bytes:, staging_records:)
          Internal.integer(record_bytes, max: (1 << 32)-1); Values.wide(staging_bytes); Internal.integer(staging_records, max: (1 << 32)-1)
          raise ArgumentError, 'Staging quota cannot hold one record' if staging_bytes < record_bytes
          super
        end
        def wire = { 'record_bytes' => record_bytes, 'staging_bytes' => staging_bytes.to_s, 'staging_records' => staging_records }
      end
      Configuration = Data.define(:scope, :owner, :administrator, :table_limits) do
        def initialize(scope:, owner:, administrator:, table_limits:)
          Connection.new(owner: owner, scope: scope)
          super(scope: scope, owner: owner, administrator: Internal.integer(administrator), table_limits: Values.typed(table_limits, TableLimits))
        end
        def wire = { 'scope' => scope.wire, 'owner' => owner.pid, 'administrator' => administrator, 'table_limits' => table_limits.wire }
      end
      Rights = Data.define(:can_inspect, :can_create, :can_read, :can_insert, :can_update, :can_delete, :can_alter, :can_drop) do
        def initialize(**rights)
          raise ArgumentError, 'Specify every Table right' unless rights.keys.sort == self.class.members.sort
          super(**rights.transform_values { |v| Internal.boolean(v) })
        end
        def wire = to_h.transform_keys { |key| key.to_s.delete_prefix('can_') }
      end
      Policy = Data.define(:scope, :principal, :revision, :rights) do
        def initialize(scope:, principal:, revision:, rights:)
          super(scope: Values.typed(scope, Scope), principal: Internal.integer(principal, min: 0), revision: Values.wide(revision), rights: Values.typed(rights, Rights))
        end
        def wire = { 'scope' => scope.wire, 'principal' => principal, 'revision' => revision.to_s }.merge(rights.wire)
      end
      PolicyChange = Data.define(:expected_revision, :policy) do
        def initialize(expected_revision:, policy:)
          Values.wide(expected_revision, min: 0); Values.typed(policy, Policy)
          raise ArgumentError, 'Policy requires the expected successor revision' unless policy.revision == expected_revision + 1
          super
        end
        def wire = { 'expected_revision' => expected_revision.to_s, 'policy' => policy.wire }
      end
      Column = Data.define(:id, :name, :type, :nullable, :default, :max_characters) do
        def initialize(id:, name:, type:, nullable: true, default: nil, max_characters: nil)
          super(id: Values.wide(id), name: Values.name(name), type: Logical.descriptor(type), nullable: Internal.boolean(nullable), default: default.nil? ? nil : Logical.cell(default), max_characters: Values.optional(max_characters) { |v| Internal.integer(v, max: (1 << 32)-1) })
        end
        def wire = { 'id' => id.to_s }.merge(Values.column(name, type, nullable, default, max_characters))
      end
      Schema = Data.define(:object, :revision, :next_column, :columns, :primary_key) do
        def initialize(object:, revision:, next_column:, columns:, primary_key: [])
          raise ArgumentError, 'Expected Table columns and explicit keys' unless columns.is_a?(Array) && columns.length.between?(1, 128) && primary_key.is_a?(Array) && primary_key.length <= columns.length
          super(object: Values.wide(object), revision: Values.wide(revision), next_column: Values.wide(next_column), columns: columns.map { |c| Values.typed(c, Column) }.freeze, primary_key: primary_key.map { |k| Values.wide(k) }.freeze)
          raise ArgumentError, 'Table schema JSON exceeds its bound' if JSON.generate(wire).bytesize > 2 * 1024 * 1024
        end
        def wire
          budget = Values::WireBudget.new(2 * 1024 * 1024)
          { 'definition' => DEFINITION, 'object' => object.to_s, 'revision' => revision.to_s, 'next_column' => next_column.to_s, 'columns' => columns.map { |c| budget.take(c.wire) }, 'primary_key' => primary_key.map(&:to_s) }
        end
      end
      Identity = Data.define(:operation, :namespace) do
        def initialize(operation:, namespace:) = super(operation: Values.wide(operation), namespace: Values.wide(namespace))
        def wire = { 'operation' => operation.to_s, 'namespace' => namespace.to_s }
      end
      Basis = Data.define(:object, :revision, :schema_fingerprint) do
        def initialize(object:, revision:, schema_fingerprint:) = super(object: Values.wide(object), revision: Values.wide(revision), schema_fingerprint: Values.digest(schema_fingerprint))
        def wire = { 'object' => object.to_s, 'revision' => revision.to_s, 'schema_fingerprint' => schema_fingerprint.unpack1('H*') }
      end
      Metadata = Data.define(:scope, :object, :revision, :name, :schema_fingerprint, :principal, :operation, :admitted_input) do
        def initialize(scope:, object:, revision:, name:, schema_fingerprint:, principal:, operation:, admitted_input:)
          super(scope: Values.typed(scope, Scope), object: Values.wide(object), revision: Values.wide(revision), name: Values.name(name), schema_fingerprint: Values.digest(schema_fingerprint), principal: Internal.integer(principal, min: 0), operation: Values.wide(operation), admitted_input: Internal.integer(admitted_input))
        end
        def basis = Basis.new(object: object, revision: revision, schema_fingerprint: schema_fingerprint)
      end
      Head = Data.define(:revision, :rows, :pending) do
        def initialize(revision:, rows:, pending:) = super(revision: Values.wide(revision), rows: Values.wide(rows, min: 0), pending: Values.wide(pending, min: 0))
      end
      Entry = Data.define(:metadata, :head)
      Definition = Data.define(:metadata, :head, :schema)
      HistoricalDefinition = Data.define(:metadata, :schema)
      Cursor = Data.define(:definition, :scope, :resource_revision, :after_object) do
        def initialize(definition:, scope:, resource_revision:, after_object:)
          super(definition: Values.definition(definition), scope: Values.typed(scope, Scope), resource_revision: Internal.integer(resource_revision, min: 0), after_object: Values.wide(after_object))
        end
        def wire = { 'definition' => definition, 'scope' => scope.wire, 'resource_revision' => resource_revision, 'after_object' => after_object.to_s }
      end
      Page = Data.define(:resource_revision, :entries, :next) do
        def initialize(resource_revision:, entries:, next:)
          revision = Internal.integer(resource_revision, min: 0)
          entries = Logical.collection(entries, Entry, 8)
          raise ArgumentError, 'Unordered or foreign page entries' unless entries.each_cons(2).all? { |a, b| a.metadata.scope == b.metadata.scope && a.metadata.object < b.metadata.object }
          cursor = binding.local_variable_get(:next)
          if cursor
            Values.typed(cursor, Cursor)
            raise ArgumentError, 'Invalid page continuation' unless cursor.resource_revision == revision && (entries.empty? || (entries.last.metadata.scope == cursor.scope && entries.last.metadata.object <= cursor.after_object))
          end
          super(resource_revision: revision, entries: entries, next: cursor)
        end
      end
      Reference = Data.define(:definition, :digest) do
        def initialize(definition:, digest:) = super(definition: Values.definition(definition), digest: Values.digest(digest))
        def wire = { 'definition' => definition, 'digest' => digest.unpack1('H*') }
      end
      SavedIntent = Data.define(:definition, :bytes) do
        def initialize(definition:, bytes:)
          bytes = Internal.bytes(bytes, LIMITS.fetch('catalog_intent_bytes')).freeze
          raise ArgumentError, 'Empty saved intent' if bytes.empty?
          super(definition: Values.definition(definition), bytes: bytes)
        end
        def wire = { 'definition' => definition, 'bytes' => bytes.unpack1('H*') }
        def inspect = '#<Transit::Station::Catalog::SavedIntent owned recovery bytes>'
      end
      Prepared = Data.define(:data) do
        def initialize(data:) = super(data: Values.text(data, LIMITS.fetch('catalog_prepared_bytes')))
        def inspect = '#<Transit::Station::Catalog::Prepared owned signed command>'
      end
      Intent = Data.define(:reference, :scope, :owner, :principal, :identity, :object, :kind)
      Compiled = Data.define(:intent, :saved)
      Counts = Data.define(:matched, :changed) do
        def initialize(matched:, changed:)
          Values.wide(matched, min: 0); Values.wide(changed, min: 0)
          raise ArgumentError, 'Changed count exceeds matched count' if changed > matched
          super
        end
      end
      Outcome = Data.define(:kind, :operation, :object, :actual_object, :phase, :terminal, :counts, :admitted_input, :completed_input, :diagnostic)
      Upload = Data.define(:phase, :received, :total)
      State = Data.define(:outcome, :upload)
      Disposition = Data.define(:input, :outcome, :diagnostic)
      Next = Data.define(:kind, :prepared, :outcome) do
        def initialize(kind:, prepared: nil, outcome: nil) = super
      end
      Progress = Data.define(:observation, :disposition, :outcome, :upload) do
        def initialize(observation:, disposition: nil, outcome: nil, upload: nil) = super
      end
      Capabilities = Data.define(:version, :definition, :max_columns, :max_rows, :max_sql_bytes, :max_intent_bytes, :max_action_bytes, :max_prepared_bytes, :resident_intents)
      Description = Data.define(:configuration, :policy, :resource_revision)
      Assignment = Data.define(:column, :value) do
        def initialize(column:, value:) = super(column: Values.wide(column), value: value == :default ? :default : Logical.cell(value))
        def wire = { 'column' => column.to_s, 'value' => value == :default ? { 'default' => {} } : { 'cell' => Logical.cell_wire(value) } }
      end
      StatePredicate = Data.define(:column, :state) do
        def initialize(column:, state:)
          Values.symbol(state, %i[missing null type_error value conflict]); super(column: Values.wide(column), state: state)
        end
        def wire = { 'atom' => { 'state' => { 'column' => column.to_s, 'value' => state.to_s } } }
      end
      Comparison = Data.define(:column, :op, :value) do
        def initialize(column:, op:, value:)
          Values.symbol(op, %i[eq ne lt le gt ge]); super(column: Values.wide(column), op: op, value: Logical.typed(value, Logical::Atom))
        end
        def wire = { 'atom' => { 'compare' => { 'column' => column.to_s, 'op' => op.to_s, 'value' => Logical.atom_wire(value) } } }
      end
      module Values
        module_function
        def assignments(value) = Logical.collection(value, Assignment, 128)
        def predicates(values)
          return nil if values.nil?
          raise ArgumentError, 'Invalid predicate instruction count' unless values.is_a?(Array) && values.length <= 64
          values.map do |value|
            raise ArgumentError, 'Expected typed predicate' unless %i[all negate conjunction disjunction].include?(value) || value.is_a?(StatePredicate) || value.is_a?(Comparison)
            value
          end.freeze
        end
        def assignment_wire(values, budget) = values.map { |v| budget.take(v.wire) }
        def predicate_wire(values, budget)
          values&.map do |value|
            wire = case value
            when :all then { 'atom' => { 'all' => {} } }
            when :negate, :conjunction, :disjunction then { value.to_s => {} }
            else value.wire
            end
            budget.take(wire)
          end
        end
      end
      Insert = Data.define(:rows) do
        def initialize(rows:)
          raise ArgumentError, 'Invalid INSERT row count' unless rows.is_a?(Array) && rows.length.between?(1, 1024)
          super(rows: rows.map { |row| Values.assignments(row) }.freeze)
        end
        def kind = :insert
        def wire
          budget = Values::WireBudget.new(LIMITS.fetch('catalog_action_bytes'))
          { 'action' => { 'insert' => rows.map { |row| Values.assignment_wire(row, budget) } }, 'predicate' => nil }
        end
      end
      Update = Data.define(:assignments, :predicate) do
        def initialize(assignments:, predicate: nil) = super(assignments: Values.assignments(assignments), predicate: Values.predicates(predicate))
        def kind = :update
        def wire
          budget = Values::WireBudget.new(LIMITS.fetch('catalog_action_bytes'))
          { 'action' => { 'update' => Values.assignment_wire(assignments, budget) }, 'predicate' => Values.predicate_wire(predicate, budget) }
        end
      end
      Delete = Data.define(:predicate) do
        def initialize(predicate: nil) = super(predicate: Values.predicates(predicate))
        def kind = :delete
        def wire = { 'action' => { 'delete' => {} }, 'predicate' => Values.predicate_wire(predicate, Values::WireBudget.new(LIMITS.fetch('catalog_action_bytes'))) }
      end
      AddColumn = Data.define(:name, :type, :nullable, :default, :max_characters) do
        def initialize(name:, type:, nullable: true, default: nil, max_characters: nil)
          c = Column.new(id: 1, name: name, type: type, nullable: nullable, default: default, max_characters: max_characters)
          super(**c.to_h.reject { |k, _| k == :id })
        end
        def wire = { 'add' => Values.column(name, type, nullable, default, max_characters) }
      end
      DropColumn = Data.define(:column) do
        def initialize(column:) = super(column: Values.wide(column))
        def wire = { 'drop' => column.to_s }
      end
      RenameColumn = Data.define(:column, :name) do
        def initialize(column:, name:) = super(column: Values.wide(column), name: Values.name(name))
        def wire = { 'rename' => { 'column' => column.to_s, 'name' => name } }
      end
      SetDefault = Data.define(:column, :value) do
        def initialize(column:, value:) = super(column: Values.wide(column), value: value.nil? ? nil : Logical.cell(value))
        def wire = { 'default' => { 'column' => column.to_s, 'value' => value.nil? ? nil : Logical.cell_wire(value) } }
      end
      SetNullable = Data.define(:column, :nullable) do
        def initialize(column:, nullable:) = super(column: Values.wide(column), nullable: Internal.boolean(nullable))
        def wire = { 'nullable' => { 'column' => column.to_s, 'value' => nullable } }
      end
      SetType = Data.define(:column, :type, :max_characters) do
        def initialize(column:, type:, max_characters: nil) = super(column: Values.wide(column), type: Logical.descriptor(type), max_characters: Values.optional(max_characters) { |v| Internal.integer(v, max: (1 << 32)-1) })
        def wire = { 'type' => { 'column' => column.to_s, 'type' => Logical.type_wire(type), 'max_characters' => max_characters } }
      end
      Create = Data.define(:schema, :if_not_exists) do
        def initialize(schema:, if_not_exists: false) = super(schema: Values.typed(schema, Schema), if_not_exists: Internal.boolean(if_not_exists))
        def kind = :create
        def object = schema.object
        def wire = { 'create' => { 'schema' => schema.wire, 'if_not_exists' => if_not_exists } }
      end
      Alter = Data.define(:basis, :change) do
        def initialize(basis:, change:)
          raise ArgumentError, 'Expected typed ALTER change' unless [AddColumn, DropColumn, RenameColumn, SetDefault, SetNullable, SetType].any? { |type| change.is_a?(type) }
          super(basis: Values.typed(basis, Basis), change: change)
        end
        def kind = :alter
        def object = basis.object
        def wire = { 'alter' => { 'basis' => basis.wire, 'change' => change.wire } }
      end
      Rename = Data.define(:basis, :name) do
        def initialize(basis:, name:) = super(basis: Values.typed(basis, Basis), name: Values.name(name))
        def kind = :rename
        def object = basis.object
        def wire = { 'rename' => { 'basis' => basis.wire, 'name' => name } }
      end
      Drop = Data.define(:basis, :if_exists) do
        def initialize(basis: nil, if_exists: false) = super(basis: Values.optional(basis) { |v| Values.typed(v, Basis) }, if_exists: Internal.boolean(if_exists))
        def kind = :drop
        def object = basis&.object || 0
        def wire = { 'drop' => { 'basis' => basis&.wire, 'if_exists' => if_exists } }
      end
      Mutate = Data.define(:basis, :mutation) do
        def initialize(basis:, mutation:)
          raise ArgumentError, 'Expected typed Table mutation' unless [Insert, Update, Delete].any? { |type| mutation.is_a?(type) }
          super(basis: Values.typed(basis, Basis), mutation: mutation)
        end
        def kind = mutation.kind
        def object = basis.object
        def wire = { 'mutate' => { 'basis' => basis.wire, 'mutation' => mutation.wire } }
      end
      Dependency = Data.define(:scope, :object, :identity, :owner, :kind) do
        def initialize(scope:, object:, identity:, owner:, kind:)
          Connection.new(owner: owner, scope: scope); Values.symbol(kind, %i[query_source writer watch maintained_relation history])
          super(scope: scope, object: Values.wide(object), identity: Values.wide(identity), owner: owner, kind: kind)
        end
        def wire(present) = { 'scope' => scope.wire, 'object' => object.to_s, 'identity' => identity.to_s, 'owner' => owner.pid, 'kind' => kind.to_s, 'present' => Internal.boolean(present) }
      end
      module Values
        module_function
        def configuration(value)
          v = object(value, %w[scope owner administrator table_limits]); s = scope(v.fetch('scope'))
          limits = object(v.fetch('table_limits'), %w[record_bytes staging_bytes staging_records])
          Configuration.new(scope: s, owner: ProcessRef.new(realm: s.resource.realm, pid: v.fetch('owner')), administrator: v.fetch('administrator'), table_limits: TableLimits.new(record_bytes: limits.fetch('record_bytes'), staging_bytes: decimal(limits.fetch('staging_bytes')), staging_records: limits.fetch('staging_records')))
        end
        def policy(value)
          names = Rights.members.map { |k| k.to_s.delete_prefix('can_') }
          v = object(value, %w[scope principal revision] + names)
          Policy.new(scope: scope(v.fetch('scope')), principal: v.fetch('principal'), revision: decimal(v.fetch('revision')), rights: Rights.new(**names.to_h { |k| ["can_#{k}".to_sym, v.fetch(k)] }))
        end
        def schema(value)
          v = object(value, %w[definition object revision next_column columns primary_key]); definition(v.fetch('definition'))
          raise IncompatibleNative, 'Invalid Table columns' unless v['columns'].is_a?(Array) && v['columns'].length.between?(1, 128) && v['primary_key'].is_a?(Array)
          columns = v.fetch('columns').map do |c|
            object(c, %w[id name type nullable default max_characters]); Column.new(id: decimal(c.fetch('id')), name: c.fetch('name'), type: Logical.type_from_wire(c.fetch('type')), nullable: c.fetch('nullable'), default: optional(c.fetch('default')) { |cell| Logical.cell_from_wire(cell) }, max_characters: c.fetch('max_characters'))
          end
          Schema.new(object: decimal(v.fetch('object')), revision: decimal(v.fetch('revision')), next_column: decimal(v.fetch('next_column')), columns: columns, primary_key: v.fetch('primary_key').map { |k| decimal(k) })
        end
        def metadata(value)
          v = object(value, %w[scope object revision name schema_fingerprint principal operation admitted_input])
          Metadata.new(scope: scope(v.fetch('scope')), object: decimal(v.fetch('object')), revision: decimal(v.fetch('revision')), name: v.fetch('name'), schema_fingerprint: Internal.unhex(v.fetch('schema_fingerprint'), 32), principal: v.fetch('principal'), operation: decimal(v.fetch('operation')), admitted_input: v.fetch('admitted_input'))
        end
        def head(value)
          v = object(value, %w[revision rows pending]); Head.new(revision: decimal(v.fetch('revision')), rows: decimal(v.fetch('rows'), min: 0), pending: decimal(v.fetch('pending'), min: 0))
        end
        def resolved(value, scope, name)
          optional(value) do |v|
            object(v, %w[metadata head schema]); result = Definition.new(metadata: metadata(v.fetch('metadata')), head: head(v.fetch('head')), schema: schema(v.fetch('schema')))
            raise IncompatibleNative, 'Foreign Table definition' unless result.metadata.scope == scope && result.metadata.name == name && result.metadata.object == result.schema.object
            result
          end
        end
        def historical(value, scope, object, revision)
          optional(value) do |v|
            object(v, %w[metadata schema]); result = HistoricalDefinition.new(metadata: metadata(v.fetch('metadata')), schema: schema(v.fetch('schema')))
            raise IncompatibleNative, 'Foreign historical definition' unless result.metadata.scope == scope && result.metadata.object == object && result.metadata.revision == revision && result.schema.object == object
            result
          end
        end
        def cursor(value)
          optional(value) do |v|
            object(v, %w[definition scope resource_revision after_object]); Cursor.new(definition: v.fetch('definition'), scope: scope(v.fetch('scope')), resource_revision: v.fetch('resource_revision'), after_object: decimal(v.fetch('after_object')))
          end
        end
        def page(value, scope, previous)
          v = object(value, %w[resource_revision entries next]); slots = v.fetch('entries')
          raise IncompatibleNative, 'Expected eight optional entry slots' unless slots.is_a?(Array) && slots.length == 8
          ended = false; entries = []
          slots.each do |slot|
            if slot.nil? then ended = true
            else
              object(slot, %w[metadata head]); entry = Entry.new(metadata: metadata(slot.fetch('metadata')), head: head(slot.fetch('head')))
              raise IncompatibleNative, 'Page has a hole or foreign scope' if ended || entry.metadata.scope != scope
              entries << entry
            end
          end
          result = Page.new(resource_revision: v.fetch('resource_revision'), entries: entries, next: cursor(v.fetch('next')))
          raise IncompatibleNative, 'Foreign continuation scope' if result.next && result.next.scope != scope
          if previous && (result.resource_revision != previous.resource_revision || (entries.first && entries.first.metadata.object <= previous.after_object) || (result.next && result.next.after_object <= previous.after_object))
            raise IncompatibleNative, 'Response does not continue its requested page'
          end
          result
        end
        def intent(value, connection, principal)
          v = object(value, %w[reference scope owner principal operation namespace object kind]); r = object(v.fetch('reference'), %w[definition digest]); s = scope(v.fetch('scope'))
          result = Intent.new(reference: Reference.new(definition: r.fetch('definition'), digest: Internal.unhex(r.fetch('digest'), 32)), scope: s, owner: ProcessRef.new(realm: s.resource.realm, pid: v.fetch('owner')), principal: Internal.integer(v.fetch('principal'), min: 0), identity: Identity.new(operation: decimal(v.fetch('operation')), namespace: decimal(v.fetch('namespace'))), object: decimal(v.fetch('object'), min: 0), kind: enum(v.fetch('kind'), KINDS))
          raise IncompatibleNative, 'Foreign intent connection' unless result.scope == connection.scope && result.owner == connection.owner && result.principal == principal
          result
        end
        def compiled(value, connection, principal, identity, kind = nil, object = nil)
          v = self.object(value, %w[intent saved]); saved = self.object(v.fetch('saved'), %w[definition bytes])
          result = Compiled.new(intent: intent(v.fetch('intent'), connection, principal), saved: SavedIntent.new(definition: saved.fetch('definition'), bytes: Internal.unhex(saved.fetch('bytes'), LIMITS.fetch('catalog_intent_bytes'))))
          raise IncompatibleNative, 'Compiled intent differs from its request' unless result.intent.identity == identity && (kind.nil? || result.intent.kind == kind) && (object.nil? || result.intent.object == object)
          result
        end
        def outcome(value)
          optional(value) do |v|
            object(v, %w[kind operation object actual_object phase terminal counts admitted_input completed_input diagnostic])
            kind = enum(v.fetch('kind'), KINDS); phase = enum(v.fetch('phase'), PHASES); terminal = Internal.boolean(v.fetch('terminal'))
            counts = optional(v.fetch('counts')) { |c| object(c, %w[matched changed]); Counts.new(matched: decimal(c.fetch('matched'), min: 0), changed: decimal(c.fetch('changed'), min: 0)) }
            raise IncompatibleNative, 'Inconsistent terminal outcome' unless terminal == %i[applied unchanged rejected cancelled].include?(phase)
            raise IncompatibleNative, 'Inconsistent mutation counts' unless !counts.nil? == (phase == :applied && %i[insert update delete].include?(kind))
            Outcome.new(kind: kind, operation: decimal(v.fetch('operation')), object: decimal(v.fetch('object'), min: 0), actual_object: optional(v.fetch('actual_object')) { |id| decimal(id, min: 0) }, phase: phase, terminal: terminal, counts: counts, admitted_input: Internal.integer(v.fetch('admitted_input')), completed_input: optional(v.fetch('completed_input')) { |position| Internal.integer(position) }, diagnostic: Value.diagnostic(v.fetch('diagnostic')))
          end
        end
        def upload(value)
          optional(value) do |v|
            object(v, %w[phase received total]); total = Internal.integer(v.fetch('total'), max: LIMITS.fetch('catalog_intent_bytes'))
            Upload.new(phase: enum(v.fetch('phase'), %i[uploading sealed ready cancelled]), received: Internal.integer(v.fetch('received'), min: 0, max: total), total: total)
          end
        end
        def state(value)
          v = object(value, %w[outcome upload]); State.new(outcome: outcome(v.fetch('outcome')), upload: upload(v.fetch('upload')))
        end
        def disposition(value)
          optional(value) do |v|
            object(v, %w[input outcome diagnostic]); Disposition.new(input: Internal.integer(v.fetch('input')), outcome: enum(v.fetch('outcome'), %i[initialized policy_applied dependency_applied invalid_command blocked denied identity_conflict stale_policy]), diagnostic: Value.diagnostic(v.fetch('diagnostic')))
          end
        end
        def next_step(value)
          kind, payload = Logical.variant(value)
          case kind
          when 'send' then Next.new(kind: :send, prepared: Prepared.new(data: payload))
          when 'terminal'
            result = outcome(payload)
            raise IncompatibleNative, 'Missing terminal outcome' unless result&.terminal
            Next.new(kind: :terminal, outcome: result)
          when 'running', 'upload_cancelled'
            object(payload, []); Next.new(kind: kind.to_sym)
          else raise IncompatibleNative, 'Unknown Table next step'
          end
        end
        def progress(value)
          kind, payload = Logical.variant(value)
          return Progress.new(observation: :pending) if kind == 'pending' && object(payload, [])
          raise IncompatibleNative, 'Unknown Table progress' unless kind == 'processed'
          v = object(payload, %w[disposition outcome upload]); Progress.new(observation: :processed, disposition: disposition(v.fetch('disposition')), outcome: outcome(v.fetch('outcome')), upload: upload(v.fetch('upload')))
        end
        def capabilities(value)
          fields = Capabilities.members.map(&:to_s); v = object(value, fields)
          definition(v.fetch('definition')); Capabilities.new(**fields.to_h { |k| [k.to_sym, k == 'definition' ? DEFINITION : Internal.integer(v.fetch(k))] })
        end
        def supported?(caps)
          caps.version == 1 && caps.max_columns == 128 && caps.max_rows == 1024 && caps.max_sql_bytes == 4096 && caps.max_intent_bytes == LIMITS.fetch('catalog_intent_bytes') && caps.max_action_bytes == LIMITS.fetch('catalog_action_bytes') && caps.max_prepared_bytes == LIMITS.fetch('catalog_prepared_bytes') && caps.resident_intents == 1
        end
        def description(value, connection, principal)
          v = object(value, %w[configuration policy resource_revision]); result = Description.new(configuration: configuration(v.fetch('configuration')), policy: policy(v.fetch('policy')), resource_revision: Internal.integer(v.fetch('resource_revision'), min: 0))
          raise IncompatibleNative, 'Foreign catalog description' unless result.configuration.scope == connection.scope && result.configuration.owner == connection.owner && result.policy.scope == connection.scope && result.policy.principal == principal
          result
        end
      end
    end
  end
end
