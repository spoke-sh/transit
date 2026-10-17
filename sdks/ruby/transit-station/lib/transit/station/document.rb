# frozen_string_literal: true
module Transit
  module Station
    DocumentDot = Data.define(:counter, :replica) do
      def initialize(counter: 0, replica: 0)
        counter = Internal.integer(counter, min: 0, max: U64_MAX)
        replica = Internal.integer(replica, min: 0, max: U64_MAX)
        raise ArgumentError, 'Root has both identities zero' unless counter.zero? == replica.zero?
        super(counter: counter, replica: replica)
      end
      def wire = { 'counter' => counter.to_s, 'replica' => replica.to_s }
    end
    DocumentValue = Data.define(:kind, :value) do
      def initialize(kind:, value: nil)
        value = case kind
        when :null, :map, :list, :text
          raise ArgumentError, 'Object/null markers have no scalar payload' unless value.nil?
          nil
        when :boolean then Internal.boolean(value)
        when :signed then Internal.integer(value, min: -(1 << 63), max: (1 << 63)-1)
        when :unsigned then Internal.integer(value, min: 0, max: U64_MAX)
        when :float
          raise ArgumentError, 'Expected finite float64' unless value.is_a?(Float) && value.finite?
          value
        when :string then Internal.text(value, 96).freeze
        when :binary then Internal.bytes(value, 96).freeze
        when :character
          text = Internal.text(value, 4)
          raise ArgumentError, 'Expected one Unicode scalar' unless text.codepoints.length == 1
          text.freeze
        else raise ArgumentError, 'Unknown Document value kind'
        end
        super(kind: kind, value: value)
      end
      def inspect = "#<Transit::Station::DocumentValue #{kind}>"
    end
    DocumentOperation = Data.define(:kind, :object, :field, :observed, :value, :element, :after) do
      def initialize(kind:, object: DocumentDot.new, field: nil, observed: [], value: nil, element: nil, after: DocumentDot.new)
        raise ArgumentError, 'Expected operation identities' unless object.is_a?(DocumentDot) && after.is_a?(DocumentDot) && (element.nil? || element.is_a?(DocumentDot))
        raise ArgumentError, 'Expected at most eight observed identities' unless observed.is_a?(Array) && observed.length <= 8 && observed.all? { |dot| dot.is_a?(DocumentDot) }
        raise ArgumentError, 'Expected DocumentValue' unless value.nil? || value.is_a?(DocumentValue)
        raise ArgumentError, 'Unknown operation' unless %i[assign remove insert set_element delete_element].include?(kind)
        super(kind: kind, object: object, field: field.nil? ? nil : Internal.text(field, 64).freeze,
          observed: observed.dup.freeze, value: value, element: element, after: after)
      end
      def self.assign(field, value, object: DocumentDot.new, observed: []) = new(kind: :assign, field: field, value: value, object: object, observed: observed)
      def self.remove(field, observed:, object: DocumentDot.new) = new(kind: :remove, field: field, observed: observed, object: object)
      def self.insert(object, value, after: DocumentDot.new) = new(kind: :insert, object: object, value: value, after: after)
      def self.set_element(object, element, value, observed:) = new(kind: :set_element, object: object, element: element, value: value, observed: observed)
      def self.delete_element(object, element) = new(kind: :delete_element, object: object, element: element)
      def inspect = "#<Transit::Station::DocumentOperation #{kind}>"
    end
    DocumentChange = Data.define(:document, :epoch, :type_revision, :replica, :previous, :first, :operations) do
      def initialize(document:, epoch:, replica:, first:, operations:, previous: 0, type_revision: 1)
        raise ArgumentError, 'Expected one to eight Document operations' unless operations.is_a?(Array) && operations.length.between?(1, 8) && operations.all? { |op| op.is_a?(DocumentOperation) }
        super(document: Internal.integer(document, max: U64_MAX), epoch: Internal.integer(epoch, max: U64_MAX),
          replica: Internal.integer(replica, max: U64_MAX), first: Internal.integer(first, max: U64_MAX), previous: Internal.integer(previous, min: 0, max: U64_MAX),
          type_revision: Internal.integer(type_revision, max: (1 << 32)-1), operations: operations.dup.freeze)
      end
      def inspect = "#<Transit::Station::DocumentChange document=#{document} replica=#{replica}>"
    end
    PreparedDocumentChange = Data.define(:document, :data) do
      def initialize(document:, data:) = super(document: Internal.integer(document, max: U64_MAX), data: Internal.bytes(data, 4096).freeze)
      def inspect = "#<Transit::Station::PreparedDocumentChange document=#{document}>"
    end
    DocumentReference = Data.define(:resource, :document, :epoch, :type_revision, :revision) do
      def initialize(resource:, document:, epoch:, type_revision:, revision:)
        raise ArgumentError, 'Expected ResourceRef' unless resource.is_a?(ResourceRef)
        super(resource: resource, document: Internal.integer(document, max: U64_MAX), epoch: Internal.integer(epoch, max: U64_MAX),
          type_revision: Internal.integer(type_revision, max: (1 << 32)-1), revision: Internal.integer(revision, min: 0, max: U64_MAX))
      end
      def encode(native_host: nil)
        Internal.unhex(DocumentValues.codec({ 'reference' => { 'resource' => resource.resource, 'document' => document.to_s,
          'epoch' => epoch.to_s, 'type_revision' => type_revision, 'revision' => revision.to_s } }, native_host).fetch('reference'), 40).freeze
      end
      def self.decode(realm, bytes, native_host: nil)
        DocumentValues.reference(realm, Internal.bytes(bytes, 40).unpack1('H*'), ->(action) { DocumentValues.codec(action, native_host) })
      end
    end
    DocumentAssignment = Data.define(:id, :value)
    DocumentField = Data.define(:status, :assignments) do
      def observed = assignments.map(&:id).freeze
    end
    DocumentDescription = Data.define(:reference, :source_revision, :floor, :merge_window, :retired, :active_job, :change_format)
    DocumentPath = Data.define(:reference, :source_revision, :field)
    DocumentItem = Data.define(:id, :field)
    DocumentPage = Data.define(:reference, :source_revision, :items, :next)
    DocumentResynchronization = Data.define(:reference, :floor, :replica, :previous_counter, :clock)
    DocumentProgress = Data.define(:phase, :revision)
    module DocumentValues
      module_function
      def codec(action, native_host)
        worker = Internal::Worker.new { Bridge.local(native_host) }
        begin worker.call { |bridge| bridge.document_codec(action) }
        ensure worker.close
        end
      end
      def scalar(value)
        raise ArgumentError, 'Expected DocumentValue' unless value.is_a?(DocumentValue)
        payload = case value.kind
        when :null, :map, :list, :text then {}
        when :signed, :unsigned then value.value.to_s
        when :float then [value.value].pack('E').unpack1('H*')
        when :binary then value.value.unpack1('H*')
        else value.value
        end
        { { null: 'null_value', float: 'float_bits' }.fetch(value.kind, value.kind.to_s) => payload }
      end
      def from_scalar(value)
        kind, payload = value.first
        case kind
        when 'null_value' then DocumentValue.new(kind: :null)
        when 'map', 'list', 'text' then DocumentValue.new(kind: kind.to_sym)
        when 'signed', 'unsigned' then DocumentValue.new(kind: kind.to_sym, value: Integer(payload, 10))
        when 'binary' then DocumentValue.new(kind: :binary, value: Internal.unhex(payload, 96))
        when 'float_bits' then DocumentValue.new(kind: :float, value: Internal.unhex(payload, 8).unpack1('E'))
        else DocumentValue.new(kind: kind.to_sym, value: payload)
        end
      end
      def dot(value) = DocumentDot.new(counter: Value.wide(value.fetch('counter')), replica: Value.wide(value.fetch('replica')))
      def operation(op)
        value = { 'object' => op.object.wire }
        value['field'] = op.field if %i[assign remove].include?(op.kind)
        value['observed'] = op.observed.map(&:wire) if %i[assign remove set_element].include?(op.kind)
        value['value'] = scalar(op.value) if %i[assign insert set_element].include?(op.kind)
        value['element'] = op.element.wire if %i[set_element delete_element].include?(op.kind)
        value['after'] = op.after.wire if op.kind == :insert
        { op.kind.to_s => value }
      end
      def from_operation(op)
        name, value = op.first
        DocumentOperation.new(kind: name.to_sym, object: dot(value.fetch('object')), field: value['field'],
          observed: value.fetch('observed', []).map { |id| dot(id) }, value: value['value'] && from_scalar(value['value']),
          element: value['element'] && dot(value['element']), after: value['after'] ? dot(value['after']) : DocumentDot.new)
      end
      def change(value)
        DocumentChange.new(document: Value.wide(value.fetch('document'), min: 1), epoch: Value.wide(value.fetch('epoch'), min: 1),
          type_revision: value.fetch('type_revision'), replica: Value.wide(value.fetch('replica'), min: 1), previous: Value.wide(value.fetch('previous')),
          first: Value.wide(value.fetch('first'), min: 1), operations: value.fetch('operations').map { |op| from_operation(op) })
      end
      def reference(realm, bytes, codec)
        value = codec.call({ 'inspect_reference' => bytes }).fetch('inspected_reference')
        DocumentReference.new(resource: ResourceRef.new(realm: realm, resource: value.fetch('resource')), document: Value.wide(value.fetch('document'), min: 1),
          epoch: Value.wide(value.fetch('epoch'), min: 1), type_revision: value.fetch('type_revision'), revision: Value.wide(value.fetch('revision')))
      end
      def field(value)
        entries = value.fetch('assignments').map { |v| DocumentAssignment.new(id: dot(v.fetch('id')), value: from_scalar(v.fetch('value'))) }.freeze
        status = value.fetch('status').to_sym
        raise IncompatibleNative, 'Invalid Document field' unless entries.length <= 8 && (status == :missing) == entries.empty? && (status == :conflict) == (entries.length > 1)
        DocumentField.new(status: status == :null_value ? :null : status, assignments: entries)
      end
    end
    private_constant :DocumentValues
    def self.prepare_document(change, native_host: nil)
      raise ArgumentError, 'Expected DocumentChange' unless change.is_a?(DocumentChange)
      value = DocumentValues.codec({ 'prepare' => { 'document' => change.document.to_s, 'epoch' => change.epoch.to_s,
        'type_revision' => change.type_revision, 'replica' => change.replica.to_s, 'first' => change.first.to_s, 'previous' => change.previous.to_s,
        'operations' => change.operations.map { |op| DocumentValues.operation(op) } } }, native_host).fetch('prepared')
      PreparedDocumentChange.new(document: change.document, data: Internal.unhex(value.fetch('bytes'), 4096))
    end
    def self.decode_document(bytes, native_host: nil)
      DocumentValues.change(DocumentValues.codec({ 'decode' => Internal.bytes(bytes, 4096).unpack1('H*') }, native_host).fetch('change'))
    end
    class DocumentOwner
      attr_reader :document
      def initialize(turn, document)
        turn.__send__(:check!)
        @turn, @document = turn, Internal.integer(document, max: U64_MAX)
      end
      def apply(action)
        @turn.__send__(:check!)
        raise UnsupportedCapability, 'Native Document owner unavailable' unless @turn.__send__(:caps)['document_owner']
        @turn.__send__(:apply_native, { 'document' => action }).fetch('document')
      end
      private :apply
      def create(type_revision: 1, record_bytes: 4096, staging_bytes: 8192, staging_records: 2)
        apply({ 'create' => { 'document' => document.to_s, 'type_revision' => Internal.integer(type_revision, max: (1 << 32)-1),
          'record_bytes' => Internal.integer(record_bytes, max: (1 << 32)-1), 'staging_bytes' => Internal.integer(staging_bytes, max: U64_MAX).to_s,
          'staging_records' => Internal.integer(staging_records, max: (1 << 32)-1) } }); nil
      end
      def stage(job, change, node_limit:)
        raise ArgumentError, 'Change belongs to another Document' unless change.is_a?(PreparedDocumentChange) && change.document == document
        result = apply({ 'stage' => { 'document' => document.to_s, 'job' => Internal.integer(job, max: U64_MAX).to_s,
          'change' => change.data.unpack1('H*'), 'node_limit' => Internal.integer(node_limit, max: (1 << 32)-1) } }).fetch('progress')
        DocumentProgress.new(phase: result.fetch('phase').to_sym, revision: result['revision'] && Value.wide(result['revision']))
      end
      def checkpoint(job)
        result = apply({ 'checkpoint' => { 'document' => document.to_s, 'job' => Internal.integer(job, max: U64_MAX).to_s } }).fetch('progress')
        DocumentProgress.new(phase: result.fetch('phase').to_sym, revision: result['revision'] && Value.wide(result['revision']))
      end
      def merge_window(revisions) = apply({ 'merge_window' => { 'document' => document.to_s, 'revisions' => Internal.integer(revisions, min: 0, max: U64_MAX).to_s } }) && nil
      def reject(job, checkpoint: false) = apply({ 'reject' => { 'document' => document.to_s, 'job' => Internal.integer(job, max: U64_MAX).to_s, 'checkpoint' => Internal.boolean(checkpoint) } }) && nil
      def collect(job, checkpoint: false, retired: false) = apply({ 'collect' => { 'document' => document.to_s, 'job' => Internal.integer(job, max: U64_MAX).to_s, 'checkpoint' => Internal.boolean(checkpoint), 'retired' => Internal.boolean(retired) } }).fetch('collected')
      def retire = apply({ 'retire' => document.to_s }) && nil
    end
    class DocumentReader
      def initialize(realm, read, codec)
        @realm, @read, @codec = realm, read, codec
      end
      def identity(resource, document)
        raise ArgumentError, 'Document belongs to another realm' unless resource.is_a?(ResourceRef) && resource.realm == @realm
        { 'resource' => resource.resource, 'document' => Internal.integer(document, max: U64_MAX).to_s }
      end
      def encoded(reference)
        raise ArgumentError, 'Document belongs to another realm' unless reference.is_a?(DocumentReference) && reference.resource.realm == @realm
        @codec.call({ 'reference' => { 'resource' => reference.resource.resource, 'document' => reference.document.to_s, 'epoch' => reference.epoch.to_s,
          'type_revision' => reference.type_revision, 'revision' => reference.revision.to_s } }).fetch('reference')
      end
      private :identity, :encoded
      def describe(resource, document)
        value = @read.call({ 'describe' => identity(resource, document) }).fetch('description')
        DocumentDescription.new(reference: DocumentValues.reference(@realm, value.fetch('reference'), @codec), source_revision: value.fetch('source_revision'),
          floor: Value.wide(value.fetch('floor')), merge_window: Value.wide(value.fetch('merge_window')), retired: value.fetch('retired'),
          active_job: Value.wide(value.fetch('active_job')), change_format: value.fetch('change_format'))
      end
      def path(reference, names)
        raise ArgumentError, 'Expected one to sixteen path segments' unless names.is_a?(Array) && names.length.between?(1, 16)
        bytes = encoded(reference)
        value = @read.call({ 'path' => { 'reference' => bytes, 'names' => names.map { |name| Internal.text(name, 64) } } }).fetch('field')
        raise IncompatibleNative, 'Document revision changed' unless value.fetch('reference') == bytes
        DocumentPath.new(reference: reference, source_revision: value.fetch('source_revision'), field: DocumentValues.field(value.fetch('value')))
      end
      def sequence(reference, object, cursor: nil)
        raise ArgumentError, 'Expected DocumentDot' unless object.is_a?(DocumentDot)
        bytes = encoded(reference)
        value = @read.call({ 'sequence' => { 'reference' => bytes, 'object' => object.wire, 'cursor' => cursor.nil? ? nil : Internal.text(cursor, 1024) } }).fetch('page')
        raise IncompatibleNative, 'Invalid Document page' unless value.fetch('reference') == bytes && value.fetch('items').length <= 8
        DocumentPage.new(reference: reference, source_revision: value.fetch('source_revision'), next: value.fetch('next')&.freeze,
          items: value.fetch('items').map { |v| DocumentItem.new(id: DocumentValues.dot(v.fetch('id')), field: DocumentValues.field(v.fetch('values'))) }.freeze)
      end
      def resynchronize(resource, document, replica)
        value = @read.call({ 'resynchronize' => { 'identity' => identity(resource, document), 'replica' => Internal.integer(replica, max: U64_MAX).to_s } }).fetch('resynchronization')
        DocumentResynchronization.new(reference: DocumentValues.reference(@realm, value.fetch('reference'), @codec), floor: Value.wide(value.fetch('floor')),
          replica: Value.wide(value.fetch('replica'), min: 1), previous_counter: Value.wide(value.fetch('previous_counter')), clock: Value.wide(value.fetch('clock')))
      end
      def accepted_change(reference) = DocumentValues.change(@read.call({ 'accepted_change' => encoded(reference) }).fetch('change'))
    end
  end
end
