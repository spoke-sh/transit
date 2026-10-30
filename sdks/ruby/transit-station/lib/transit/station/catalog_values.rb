# frozen_string_literal: true
module Transit
  module Station
    module Catalog
      # Shared package decoders keep neutral values behind the language-native
      # API while allowing query lookup to reuse the catalog's schema owner.
      def Internal.catalog_scope(value) = Values.scope(value)
      def Internal.catalog_schema(value) = Values.schema(value)
      CONTRACT = JSON.parse(File.binread(File.join(__dir__, 'contract.json'))).freeze
      DEFINITION = CONTRACT.fetch('definition').freeze
      LIMITS = CONTRACT.fetch('limits').freeze
      ENCODINGS = %i[plain bitpacked rle dictionary fsst comp comp_3 zoned ibm_hfp ebcdic].freeze
      COLLATIONS = %i[none utf8_binary ascii_ci ebcdic_cp037 icu_root].freeze
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
        def column(name, type, nullable, default, max_characters, encoding, collation)
          { 'name' => self.name(name), 'type' => Logical.type_wire(type), 'nullable' => Internal.boolean(nullable), 'default' => default.nil? ? nil : Logical.cell_wire(default), 'max_characters' => optional(max_characters) { |v| Internal.integer(v, max: (1 << 32)-1) }, 'encoding' => symbol(encoding, ENCODINGS), 'collation' => symbol(collation, COLLATIONS) }
        end
      end
      private_constant :CONTRACT, :Values
      Scope = Data.define(:resource, :catalog) do
        def initialize(resource:, catalog:) = super(resource: Values.typed(resource, ResourceRef), catalog: Values.wide(catalog))
        def wire = { 'realm' => resource.realm, 'resource' => resource.resource, 'catalog' => catalog.to_s }
      end
      Connection = Data.define(:scope, :audience, :branch, :role) do
        def initialize(scope:, audience:, branch: 1, role: nil)
          super(scope: Values.typed(scope, Scope), audience: Internal.integer(audience), branch: Values.wide(branch), role: role.nil? ? nil : Internal.integer(role, min: 0))
        end
        def wire(principal) = { 'scope' => scope.wire, 'branch' => branch.to_s, 'audience' => audience, 'principal' => Internal.integer(principal, min: 0), 'role' => role }
      end
      TableLimits = Data.define(:record_bytes, :staging_bytes, :staging_records) do
        def initialize(record_bytes:, staging_bytes:, staging_records:)
          Internal.integer(record_bytes, max: (1 << 32)-1); Values.wide(staging_bytes); Internal.integer(staging_records, max: (1 << 32)-1)
          raise ArgumentError, 'Staging quota cannot hold one record' if staging_bytes < record_bytes
          super
        end
        def wire = { 'record_bytes' => record_bytes, 'staging_bytes' => staging_bytes.to_s, 'staging_records' => staging_records }
      end
      # These opaque IDs are allocated by public native provisioning.
      AuthorityProfile = Data.define(:database_domain, :schema_domain, :table_domain, :stream_domain, :queue_domain, :kv_domain, :database, :initial_schema, :initial_schema_authority) do
        def initialize(**values)
          raise ArgumentError, 'Specify every native authorization binding' unless values.keys.sort == self.class.members.sort
          values.each_value { |value| Internal.integer(value) }
          unless [values[:database_domain], values[:schema_domain], values[:table_domain], values[:stream_domain], values[:queue_domain], values[:kv_domain]].uniq.length == 6 && values[:database] != values[:initial_schema_authority]
            raise ArgumentError, 'Distinct native authorization bindings are required'
          end
          super
        end
        def wire = to_h.transform_keys(&:to_s)
      end
      # An observation of the authenticated caller, not a reusable capability.
      Subject = Data.define(:principal, :login_role, :role, :credential_epoch, :audience, :context) do
        def initialize(principal:, login_role:, role:, credential_epoch:, audience:, context:)
          super(principal: Internal.integer(principal, min: 0), login_role: Internal.integer(login_role, min: 0),
            role: Internal.integer(role, min: 0), credential_epoch: Internal.integer(credential_epoch),
            audience: Internal.integer(audience), context: Values.digest(context))
        end
      end
      Column = Data.define(:id, :name, :type, :nullable, :default, :max_characters, :encoding, :collation) do
        def initialize(id:, name:, type:, nullable: true, default: nil, max_characters: nil, encoding: :plain, collation: :none)
          Values.symbol(encoding, ENCODINGS); Values.symbol(collation, COLLATIONS)
          super(id: Values.wide(id), name: Values.name(name), type: Logical.descriptor(type), nullable: Internal.boolean(nullable), default: default.nil? ? nil : Logical.cell(default), max_characters: Values.optional(max_characters) { |v| Internal.integer(v, max: (1 << 32)-1) }, encoding: encoding, collation: collation)
        end
        def wire = { 'id' => id.to_s }.merge(Values.column(name, type, nullable, default, max_characters, encoding, collation))
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
        def initialize(operation:, namespace: 1) = super(operation: Values.wide(operation), namespace: Internal.integer(namespace))
      end
      Counts = Data.define(:matched, :changed) do
        def initialize(matched:, changed:)
          Values.wide(matched, min: 0); Values.wide(changed, min: 0)
          raise ArgumentError, 'Changed count exceeds matched count' if changed > matched
          super
        end
      end
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
      AddColumn = Data.define(:name, :type, :nullable, :default, :max_characters, :encoding, :collation) do
        def initialize(name:, type:, nullable: true, default: nil, max_characters: nil, encoding: :plain, collation: :none)
          c = Column.new(id: 1, name: name, type: type, nullable: nullable, default: default, max_characters: max_characters, encoding: encoding, collation: collation)
          super(**c.to_h.reject { |k, _| k == :id })
        end
        def wire = { 'add' => Values.column(name, type, nullable, default, max_characters, encoding, collation) }
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
      SetPhysical = Data.define(:column, :encoding, :collation) do
        def initialize(column:, encoding:, collation:)
          Values.symbol(encoding, ENCODINGS); Values.symbol(collation, COLLATIONS)
          super(column: Values.wide(column), encoding: encoding, collation: collation)
        end
        def wire = { 'physical' => { 'column' => column.to_s, 'encoding' => encoding.to_s, 'collation' => collation.to_s } }
      end
      Create = Data.define(:schema, :if_not_exists) do
        def initialize(schema:, if_not_exists: false) = super(schema: Values.typed(schema, Schema), if_not_exists: Internal.boolean(if_not_exists))
        def kind = :create
        def object = schema.object
        def wire = { 'create' => { 'schema' => schema.wire, 'if_not_exists' => if_not_exists } }
      end
      Alter = Data.define(:basis, :change) do
        def initialize(basis:, change:)
          raise ArgumentError, 'Expected typed ALTER change' unless [AddColumn, DropColumn, RenameColumn, SetDefault, SetNullable, SetType, SetPhysical].any? { |type| change.is_a?(type) }
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
      Mutate = Data.define(:basis, :mutation, :ingestion) do
        def initialize(basis:, mutation:, ingestion: :point)
          raise ArgumentError, 'Expected typed Table mutation' unless [Insert, Update, Delete].any? { |type| mutation.is_a?(type) }
          Values.symbol(ingestion, %i[point bulk]); super(basis: Values.typed(basis, Basis), mutation: mutation, ingestion: ingestion)
        end
        def kind = mutation.kind
        def object = basis.object
        def wire = { 'mutate' => { 'basis' => basis.wire, 'mutation' => mutation.wire, 'ingestion' => ingestion.to_s } }
      end
      module Values
        module_function
        def schema(value)
          v = object(value, %w[definition object revision next_column columns primary_key]); definition(v.fetch('definition'))
          raise IncompatibleNative, 'Invalid Table columns' unless v['columns'].is_a?(Array) && v['columns'].length.between?(1, 128) && v['primary_key'].is_a?(Array)
          columns = v.fetch('columns').map do |c|
            object(c, %w[id name type nullable default max_characters encoding collation]); Column.new(id: decimal(c.fetch('id')), name: c.fetch('name'), type: Logical.type_from_wire(c.fetch('type')), nullable: c.fetch('nullable'), default: optional(c.fetch('default')) { |cell| Logical.cell_from_wire(cell) }, max_characters: c.fetch('max_characters'), encoding: enum(c.fetch('encoding'), ENCODINGS), collation: enum(c.fetch('collation'), COLLATIONS))
          end
          Schema.new(object: decimal(v.fetch('object')), revision: decimal(v.fetch('revision')), next_column: decimal(v.fetch('next_column')), columns: columns, primary_key: v.fetch('primary_key').map { |k| decimal(k) })
        end
      end
      # Local values preserve exact bindings. Shared Zig remains the authority
      # for signatures, admission, result truth and current access.
      module Values
        SCHEMAS = JSON.parse(File.binread(File.join(__dir__, 'schemas.json'))).freeze
        class UniqueObject < Hash
          def []=(key, value)
            raise ArgumentError, 'Duplicate saved field' if key?(key)
            super
          end
        end
        module_function
        def parse(data)
          JSON.parse(text(data, LIMITS.fetch('catalog_action_bytes')), object_class: UniqueObject, max_nesting: 96)
        rescue JSON::ParserError, JSON::NestingError
          raise ArgumentError, 'Invalid saved catalog value'
        end
        def validate(name, value)
          raise IncompatibleNative, 'Invalid current catalog contract' unless Internal.valid?(SCHEMAS.fetch(name), value)
          value
        end
        def action(value) = validate('CatalogAction', value)
        def variant(value) = Logical.variant(value)
        def digest_hex(value)
          bytes = Internal.unhex(value, 32)
          raise ArgumentError, 'Expected complete digest' unless bytes.bytesize == 32
          bytes.freeze
        end
        def position(value) = Position.new(partition: decimal(value.fetch('partition')), next_lsn: decimal(value.fetch('next_lsn'), min: 0))
        def connection(value)
          Internal.integer(value.fetch('principal'), min: 0)
          Connection.new(scope: scope(value.fetch('scope')), audience: value.fetch('audience'), branch: decimal(value.fetch('branch')), role: value.fetch('role'))
        end
        def object_identity(value)
          ObjectIdentity.new(scope: scope(value.fetch('scope')), branch: decimal(value.fetch('branch')), object: decimal(value.fetch('object')))
        end
        def interpretation(value)
          Interpretation.new(object: object_identity(value.fetch('object')), revision: decimal(value.fetch('revision')), digest: digest_hex(value.fetch('digest')))
        end
        def content(value) = Content.new(bytes: decimal(value.fetch('bytes')), sha256: digest_hex(value.fetch('sha256')))
        def stored(value)
          result = StoredDefinition.new(interpretation: interpretation(value.fetch('interpretation')), content: content(value.fetch('content')),
            schema_fingerprint: digest_hex(value.fetch('schema_fingerprint')), retired: Internal.boolean(value.fetch('retired')))
          raise ArgumentError, 'Stored definition digest changed' unless result.interpretation.digest == result.content.sha256
          result
        end
        def owns(connection, target)
          raise ArgumentError, 'Foreign catalog object' unless connection.scope == target.scope && connection.branch == target.branch
        end
        def binding(value)
          definition(value.fetch('definition')); identity = value.fetch('identity')
          original_scope = scope(identity.fetch('scope')); Internal.integer(identity.fetch('principal'), min: 0); decimal(identity.fetch('operation'))
          target = object_identity(value.fetch('target')); digest_hex(value.fetch('intent'))
          raise ArgumentError, 'Foreign operation target' unless target.scope == original_scope
          expected = optional(value.fetch('expected_definition')) { |v| interpretation(v) }
          raise ArgumentError, 'Foreign expected definition' if expected && expected.object != target
          optional(value.fetch('expected_data')) { |v| position(v) }
          if value.fetch('action') == 'create'
            raise ArgumentError, 'CREATE has existing expectations' if expected || value['expected_data']
          else
            raise ArgumentError, 'Missing expected definition' unless expected
          end
          value
        end
        def assertion(value)
          definition(value.fetch('definition')); c = connection(value.fetch('connection'))
          Internal.integer(value.fetch('namespace')); name(value.fetch('name')); decimal(value.fetch('operation')); digest_hex(value.fetch('intent'))
          expected = optional(value.fetch('expected')) { |v| interpretation(v) }
          owns(c, expected.object) if expected
          raise ArgumentError, 'Invalid conditional binding' unless (value.fetch('action') == 'create_if_not_exists') == !expected.nil?
          value
        end
        def check_binding(value, c, principal)
          binding(value)
          raise ArgumentError, 'Foreign original caller' unless value['identity']['principal'] == principal && scope(value['identity']['scope']) == c.scope
          owns(c, object_identity(value.fetch('target')))
        end
        def capabilities(value)
          definition(value.fetch('definition'))
          result = Capabilities.new(**value.transform_keys(&:to_sym))
          raise UnsupportedCapability, 'Native direct catalog capability mismatch' unless
            result.version == 1 && result.max_columns == 128 && result.max_rows == 1024 && result.max_sql_bytes == 4096 &&
            result.max_intent_bytes == LIMITS.fetch('catalog_intent_bytes') && result.max_action_bytes == LIMITS.fetch('catalog_action_bytes') &&
            result.metadata_page_entries == 8 && result.resident_intents == 1
          result
        end
        def description(value, c, principal)
          raw = value.fetch('configuration'); verified = value.fetch('subject')
          config = Configuration.new(scope: scope(raw.fetch('scope')), branch: decimal(raw.fetch('branch')), partition: decimal(raw.fetch('partition')),
            audience: Internal.integer(raw.fetch('audience')), authority: AuthorityProfile.new(**raw.fetch('authority').transform_keys(&:to_sym)),
            database_name: name(raw.fetch('database_name')), initial_schema_name: name(raw.fetch('initial_schema_name')))
          context = verified.fetch('context').map { |byte| Internal.integer(byte, min: 0, max: 255) }.pack('C*')
          subject = Subject.new(**verified.except('context').transform_keys(&:to_sym), context: context)
          raise IncompatibleNative, 'Foreign catalog description' unless config.scope == c.scope && config.branch == c.branch && config.audience == c.audience &&
            subject.principal == principal && subject.audience == c.audience && (c.role.nil? || subject.role == c.role)
          Description.new(configuration: config, subject: subject, policy_revision: Internal.integer(value.fetch('policy_revision'), min: 0))
        end
        def metadata(value, c, principal, namespace, name)
          return nil if value.nil?
          basis = Basis.restore(JSON.generate(value.fetch('binding')))
          raise IncompatibleNative, 'Foreign Table lookup' unless basis.connection == c && basis.principal == principal && basis.namespace == namespace && basis.name == name
          schema = schema(value.fetch('schema'))
          raise IncompatibleNative, 'Foreign Table schema' unless schema.object == basis.object
          Metadata.new(basis: basis, authorization: Internal.integer(value.fetch('authorization')), position: position(value.fetch('position')),
            changed_lsn: decimal(value.fetch('changed_lsn'), min: 0), row_count: decimal(value.fetch('row_count'), min: 0), schema: schema)
        end
        def summary(value, saved, c, principal, identity = nil)
          id = value.fetch('id'); definition(id.fetch('definition')); digest_hex(id.fetch('digest'))
          namespace = Internal.integer(value.fetch('namespace')); kind, b = variant(value.fetch('binding'))
          if kind == 'table'
            check_binding(b, c, principal); operation = decimal(b.fetch('identity').fetch('operation'))
          else
            assertion(b); operation = decimal(b.fetch('operation'))
            raise IncompatibleNative, 'Foreign name binding' unless b.fetch('connection') == c.wire(principal) && b.fetch('namespace') == namespace
          end
          raise IncompatibleNative, 'Substituted prepared identity' if identity && (identity.operation != operation || identity.namespace != namespace)
          saved_kind, saved_raw = variant(saved.wire)
          raise IncompatibleNative, 'Changed saved work' unless saved_kind == kind && saved_raw.fetch('namespace') == namespace
          raise IncompatibleNative, 'Changed name assertion' if kind == 'name_assertion' && saved_raw != b
          Intent.new(id_data: JSON.generate(id).freeze, binding_data: JSON.generate(b).freeze, kind: kind.to_sym, namespace: namespace,
            identity: Identity.new(operation: operation, namespace: namespace), saved: saved)
        end
        def observation(value, original)
          kind, tagged = variant(value); state, raw = variant(tagged); b = original.binding
          expected = original.kind == :name_assertion ? 'name_assertion' : (%w[insert update delete].include?(b.fetch('action')) ? 'rows' : 'ddl')
          raise IncompatibleNative, 'Changed observation kind' unless kind == expected
          return Observation.new(kind: kind.to_sym, state: :not_observed, reference: original) if state == 'not_observed'
          raise IncompatibleNative, 'Changed original binding' unless raw.fetch('binding') == b
          if kind == 'name_assertion'
            return Observation.new(kind: :name_assertion, state: raw.fetch('state').to_sym, reference: original,
              reason: raw.fetch('reason').to_sym, position: position(raw.fetch('position')))
          end
          if state == 'committed'
            result = stored(raw.fetch('resulting')); outcome = raw.fetch('outcome')
            matched = decimal(outcome.fetch('matched'), min: 0); affected = decimal(outcome.fetch('affected'), min: 0)
            raise IncompatibleNative, 'Changed commit evidence' unless affected <= matched && result.interpretation.object == object_identity(b.fetch('target'))
            commit = Commit.new(definition: result, position: position(outcome.fetch('position')), matched: matched, affected: affected, live_rows: decimal(outcome.fetch('live_rows'), min: 0))
            return Observation.new(kind: kind.to_sym, state: :committed, reference: original, commit: commit)
          end
          content(raw.fetch('intent'))
          phase = raw.fetch('phase'); reason = raw.fetch('reason')
          raise IncompatibleNative, 'Inconsistent operation phase' unless state == 'admitted' ? %w[admitted ready settled].include?(phase) : state == phase
          if kind == 'rows'
            basis = raw.fetch('basis'); interpretation(basis.fetch('interpretation')); position(basis.fetch('position')); decimal(basis.fetch('changed_lsn'), min: 0)
          end
          Observation.new(kind: kind.to_sym, state: state.to_sym, reference: original, phase: phase.to_sym, reason: reason.to_sym)
        end
        def preview(value, intent)
          kind, raw = variant(value)
          expected = intent.kind == :name_assertion ? 'name_assertion' : (%w[insert update delete].include?(intent.binding.fetch('action')) ? 'rows' : 'ddl')
          raise IncompatibleNative, 'Changed preview binding' unless kind == expected && raw.fetch('binding') == intent.binding
          current = optional(raw.fetch('current')) do |v|
            if kind == 'name_assertion' then interpretation(v)
            else CurrentBasis.new(definition: stored(v.fetch('interpretation')), position: position(v.fetch('position')), changed_lsn: decimal(v.fetch('changed_lsn'), min: 0), row_count: decimal(v.fetch('row_count'), min: 0))
            end
          end
          Preview.new(kind: kind.to_sym, intent: intent, position: position(raw.fetch(kind == 'name_assertion' ? 'position' : 'directory_position')),
            current: current, reason: raw['reason']&.to_sym, work: raw['work']&.to_sym, rebuild_key: raw['rebuild_key'],
            schema_fingerprint: optional(raw['schema_fingerprint']) { |v| digest_hex(v) }, matches: raw['matches'])
        end
        def namespace(value)
          return nil if value.nil?
          Namespace.new(scope: scope(value.fetch('scope')), id: Internal.integer(value.fetch('id')), name: name(value.fetch('name')), authorization: Internal.integer(value.fetch('authorization')), revision: Internal.integer(value.fetch('revision')), retired: Internal.boolean(value.fetch('retired')))
        end
        def page(value, c, principal, selection, previous)
          position = position(value.fetch('position')); entries = []; ended = false
          value.fetch('entries').each do |raw|
            if raw.nil? then ended = true; next; end
            raise IncompatibleNative, 'Hole in catalog page' if ended
            entry = if selection.key?('namespaces')
              found = namespace(raw)
              raise IncompatibleNative, 'Foreign namespace page' unless found.scope == c.scope
              found
            else
              interpretation = interpretation(raw.fetch('interpretation')); owns(c, interpretation.object)
              raise IncompatibleNative, 'Foreign page namespace' unless raw.fetch('namespace') == selection.fetch('tables')
              Entry.new(interpretation: interpretation, namespace: raw.fetch('namespace'), name: name(raw.fetch('name')), position: position(raw.fetch('position')), changed_lsn: decimal(raw.fetch('changed_lsn'), min: 0))
            end
            id = entry.is_a?(Namespace) ? entry.id : entry.interpretation.object.object
            last = entries.last
            prior = last ? (last.is_a?(Namespace) ? last.id : last.interpretation.object.object) : previous&.after || 0
            raise IncompatibleNative, 'Unordered catalog page' unless id > prior
            entries << entry
          end
          cursor = optional(value.fetch('next')) { |v| Cursor.restore(JSON.generate(v)) }
          if cursor
            cursor.check(c, principal, selection)
            last = entries.last; last_id = last ? (last.is_a?(Namespace) ? last.id : last.interpretation.object.object) : 0
            raise IncompatibleNative, 'Invalid continuation' unless cursor.position == position && cursor.after >= last_id && cursor.after > (previous&.after || 0)
          end
          raise IncompatibleNative, 'Changed directory position' if previous && previous.position != position
          Page.new(position: position, entries: entries.freeze, next: cursor, consistency: selection.key?('tables') ? :independent : nil)
        end
        def read_authority(raw)
          ids = %w[database schema table].map { |key| Internal.integer(raw.fetch(key)) }
          raise IncompatibleNative, 'Conflicting read authority identities' unless ids.uniq.length == 3
          ReadAuthority.new(database: ids[0], schema: ids[1], table: ids[2])
        end
      end
      Position = Data.define(:partition, :next_lsn) do
        def initialize(partition:, next_lsn:) = super(partition: Values.wide(partition), next_lsn: Values.wide(next_lsn, min: 0))
        def wire = { 'partition' => partition.to_s, 'next_lsn' => next_lsn.to_s }
      end
      ObjectIdentity = Data.define(:scope, :branch, :object) do
        def initialize(scope:, branch:, object:) = super(scope: Values.typed(scope, Scope), branch: Values.wide(branch), object: Values.wide(object))
        def wire = { 'scope' => scope.wire, 'branch' => branch.to_s, 'object' => object.to_s }
      end
      Interpretation = Data.define(:object, :revision, :digest)
      Content = Data.define(:bytes, :sha256)
      StoredDefinition = Data.define(:interpretation, :content, :schema_fingerprint, :retired)
      Configuration = Data.define(:scope, :branch, :partition, :audience, :authority, :database_name, :initial_schema_name)
      Description = Data.define(:configuration, :subject, :policy_revision)
      Capabilities = Data.define(:version, :definition, :max_columns, :max_rows, :max_sql_bytes, :max_intent_bytes, :max_action_bytes, :metadata_page_entries, :resident_intents)
      Metadata = Data.define(:basis, :authorization, :position, :changed_lsn, :row_count, :schema)
      Namespace = Data.define(:scope, :id, :authorization, :name, :revision, :retired)
      Entry = Data.define(:interpretation, :namespace, :name, :position, :changed_lsn)
      Page = Data.define(:position, :entries, :next, :consistency)
      Commit = Data.define(:definition, :position, :matched, :affected, :live_rows)
      Observation = Data.define(:kind, :state, :reference, :commit, :phase, :reason, :position) do
        def initialize(kind:, state:, reference:, commit: nil, phase: nil, reason: nil, position: nil) = super
      end
      CurrentBasis = Data.define(:definition, :position, :changed_lsn, :row_count)
      Preview = Data.define(:kind, :intent, :position, :current, :reason, :work, :rebuild_key, :schema_fingerprint, :matches)
      Compiled = Data.define(:intent, :saved)
      Intent = Data.define(:id_data, :binding_data, :kind, :namespace, :identity, :saved) do
        def id = JSON.parse(id_data)
        def binding = JSON.parse(binding_data)
      end
      class Saved
        def self.restore(data) = new(data)
        def initialize(data)
          raw = Values.parse(data)
          validate(raw)
          @data = JSON.generate(raw).freeze
          freeze
        end
        def save = @data
        def wire = JSON.parse(@data)
        def inspect = "#<#{self.class.name} owned saved binding>"
        def ==(other) = other.instance_of?(self.class) && wire == other.wire
      end
      private_constant :Saved
      class Basis < Saved
        def validate(raw)
          Values.action({ 'prepare' => { 'definition' => DEFINITION, 'namespace' => 1, 'operation' => '1', 'name' => 'check', 'action' => { 'drop' => { 'basis' => raw, 'if_exists' => false } } } })
          Values.definition(raw.fetch('definition')); Values.name(raw.fetch('name')); Internal.integer(raw.fetch('namespace'))
          c = Values.connection(raw.fetch('connection')); stored = Values.stored(raw.fetch('interpretation')); Values.owns(c, stored.interpretation.object)
          raise ArgumentError, 'Cannot prepare from a retired definition' if stored.retired
        end
        def connection = Values.connection(wire.fetch('connection'))
        def principal = wire.fetch('connection').fetch('principal')
        def namespace = wire.fetch('namespace')
        def name = wire.fetch('name').freeze
        def interpretation = Values.stored(wire.fetch('interpretation'))
        def object = interpretation.interpretation.object.object
        private :validate
      end
      class SavedIntent < Saved
        def validate(raw)
          Values.action({ 'load' => raw }); kind, value = Values.variant(raw)
          if kind == 'table'
            Values.definition(value.fetch('definition')); Internal.integer(value.fetch('namespace'))
            raise ArgumentError, 'Empty saved intent' if Internal.unhex(value.fetch('bytes'), LIMITS.fetch('catalog_intent_bytes')).empty?
          else Values.assertion(value)
          end
        end
        private :validate
      end
      class Reference < Saved
        def validate(raw)
          Values.action({ 'admit' => raw }); kind, value = Values.variant(raw)
          if kind == 'table'
            Values.definition(value.fetch('definition')); c = Values.connection(value.fetch('connection')); Internal.integer(value.fetch('namespace'))
            Values.check_binding(value.fetch('binding'), c, value.fetch('connection').fetch('principal')); content = Values.content(value.fetch('content'))
            raise ArgumentError, 'Invalid saved intent length' unless content.bytes.between?(37, LIMITS.fetch('catalog_intent_bytes'))
          else Values.assertion(value)
          end
        end
        def kind = wire.keys.first.to_sym
        def binding = kind == :table ? wire.fetch('table').fetch('binding') : wire.fetch('name_assertion')
        def connection = Values.connection(wire.values.first.fetch('connection'))
        def principal = wire.values.first.fetch('connection').fetch('principal')
        private :validate
      end
      class Cursor < Saved
        def validate(raw)
          selection = raw.fetch('selection')
          action = selection.key?('namespaces') ? { 'namespaces' => raw } : { 'tables' => { 'namespace' => selection.fetch('tables'), 'cursor' => raw } }
          Values.action({ 'catalog' => action }); Values.definition(raw.fetch('definition')); Values.connection(raw.fetch('connection')); Values.position(raw.fetch('position'))
          after = Values.decimal(raw.fetch('after')); Internal.integer(after) if selection.key?('namespaces')
          raise ArgumentError, 'Invalid directory cut' if Values.position(raw.fetch('position')).next_lsn.zero?
        end
        def check(connection, principal, selection)
          value = wire
          raise ArgumentError, 'Foreign continuation' unless value.fetch('connection') == connection.wire(principal) && value.fetch('selection') == selection
        end
        def position = Values.position(wire.fetch('position'))
        def after = Values.decimal(wire.fetch('after'))
        private :validate
      end
      class SnapshotOwner < Saved
        def validate(raw)
          Values.action({ 'retention' => { 'status' => raw } }); Values.definition(raw.fetch('definition'))
          Values.owns(Values.connection(raw.fetch('connection')), Values.object_identity(raw.fetch('object'))); Values.decimal(raw.fetch('operation'))
        end
        def connection = Values.connection(wire.fetch('connection'))
        def principal = wire.fetch('connection').fetch('principal')
        def object = Values.object_identity(wire.fetch('object'))
        def operation = Values.decimal(wire.fetch('operation'))
        private :validate
      end
      class SnapshotAcquisition < Saved
        def validate(raw)
          Values.action({ 'retention' => { 'acquire' => raw } }); SnapshotOwner.restore(JSON.generate(raw.fetch('owner'))); Values.position(raw.fetch('expected'))
        end
        def owner = SnapshotOwner.restore(JSON.generate(wire.fetch('owner')))
        def expected = Values.position(wire.fetch('expected'))
        private :validate
      end
      class Snapshot < Saved
        def validate(raw)
          Values.action({ 'retention' => { 'metadata' => raw } }); SnapshotOwner.restore(JSON.generate(raw.fetch('owner'))); Values.content(raw.fetch('content'))
        end
        def owner = SnapshotOwner.restore(JSON.generate(wire.fetch('owner')))
        def content = Values.content(wire.fetch('content'))
        private :validate
      end
      ReadAuthority = Data.define(:database, :schema, :table)
      SnapshotStatus = Data.define(:owner, :current_interpretation, :current_position, :retired, :snapshot, :released, :authority)
      SnapshotMetadata = Data.define(:snapshot, :interpretation, :accepted, :changed_lsn, :row_count, :schema, :authority)
    end
  end
end
