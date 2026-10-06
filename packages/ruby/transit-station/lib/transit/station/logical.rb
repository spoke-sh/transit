# frozen_string_literal: true
module Transit
  module Station
    # Owned language-native logical values; shared Zig owns domain semantics.
    module Logical
      SCALARS = %i[int8 int16 int32 int64 int128 uint8 uint16 uint32 uint64 uint128 float32 float64 boolean utf8 binary date time interval uuid json].freeze
      KINDS = (SCALARS + %i[decimal timestamp structure tagged_union list array map]).freeze
      Scalar = Data.define(:kind) do
        def initialize(kind:)
          raise ArgumentError, 'Unknown logical scalar' unless SCALARS.include?(kind)
          super
        end
      end
      Decimal = Data.define(:precision, :scale)
      Timestamp = Data.define(:zone)
      Field = Data.define(:name, :type, :nullable, :optional) do
        def initialize(name:, type:, nullable: false, optional: false)
          super(name: Internal.text(name, 4096).freeze, type: Logical.descriptor(type), nullable: Internal.boolean(nullable), optional: Internal.boolean(optional))
        end
      end
      Element = Data.define(:type, :nullable) do
        def initialize(type:, nullable: false)
          super(type: Logical.descriptor(type), nullable: Internal.boolean(nullable))
        end
      end
      Structure = Data.define(:fields) do
        def initialize(fields:) = super(fields: Logical.collection(fields, Field, 256))
      end
      Union = Data.define(:fields) do
        def initialize(fields:) = super(fields: Logical.collection(fields, Field, 256))
      end
      List = Data.define(:element) do
        def initialize(element:) = super(element: Logical.typed(element, Element))
      end
      ArrayType = Data.define(:element, :length) do
        def initialize(element:, length:) = super(element: Logical.typed(element, Element), length: Internal.integer(length, max: (1 << 32)-1))
      end
      Map = Data.define(:key, :value) do
        def initialize(key:, value:) = super(key: Logical.descriptor(key), value: Logical.typed(value, Element))
      end
      DESCRIPTORS = [Scalar, Decimal, Timestamp, Structure, Union, List, ArrayType, Map].freeze
      Interval = Data.define(:months, :days, :nanos)
      Atom = Data.define(:kind, :value, :width) do
        def initialize(kind:, value:, width: nil)
          value = Internal.bytes(value, 1024 * 1024).freeze if %i[binary uuid].include?(kind)
          value = Internal.text(value, 1024 * 1024).freeze if kind == :utf8
          super
        end
      end
      Sequence = Data.define(:kind, :cells) do
        def initialize(kind:, cells:)
          raise ArgumentError, 'Unknown logical sequence' unless %i[structure list array].include?(kind)
          super(kind: kind, cells: Logical.cells(cells))
        end
      end
      MapEntry = Data.define(:key, :value) do
        def initialize(key:, value:) = super(key: Logical.typed(key, Atom), value: Logical.cell(value))
      end
      MapValue = Data.define(:entries) do
        def initialize(entries:) = super(entries: Logical.collection(entries, MapEntry, 32767))
      end
      Tagged = Data.define(:index, :value) do
        def initialize(index:, value:) = super(index: Internal.integer(index, min: 0, max: 255), value: Logical.cell(value))
      end
      Json = Data.define(:json) do
        def initialize(json:) = super(json: Internal.text(json, 1024 * 1024).freeze)
      end
      Missing = Data.define
      Null = Data.define
      SourceTypeError = Data.define(:actual) do
        def initialize(actual:)
          raise ArgumentError, 'Unknown logical source type' unless KINDS.include?(actual)
          super
        end
      end
      Present = Data.define(:value) do
        def initialize(value:)
          raise ArgumentError, 'Expected typed logical value' unless [Atom, Sequence, MapValue, Tagged, Json].any? { |type| value.is_a?(type) }
          super
        end
      end
      Alternative = Data.define(:counter, :replica, :value) do
        def initialize(counter:, replica:, value:)
          raise ArgumentError, 'Invalid conflict alternative' unless [Null, SourceTypeError, Present].any? { |type| value.is_a?(type) }
          super(counter: Internal.integer(counter, max: U64_MAX), replica: Internal.integer(replica, max: U64_MAX), value: value)
        end
      end
      Conflict = Data.define(:alternatives) do
        def initialize(alternatives:)
          items = Logical.collection(alternatives, Alternative, 8)
          raise ArgumentError, 'Expected two to eight increasing conflict dots' unless items.length >= 2 && items.each_cons(2).all? { |a, b| ([a.counter, a.replica] <=> [b.counter, b.replica]) == -1 }
          super(alternatives: items)
        end
      end
      CELLS = [Missing, Null, SourceTypeError, Present, Conflict].freeze
      class Budget
        def initialize(maximum)
          @maximum, @nodes, @bytes, @names = maximum, 0, 0, 0
        end
        def enter(depth)
          @nodes += 1
          raise ArgumentError, 'Logical nesting or child bound exceeded' if depth >= 16 || @nodes > @maximum
        end
        def data(length)
          @bytes += length
          raise ArgumentError, 'Logical byte bound exceeded' if @bytes > 1024 * 1024
        end
        def name(value)
          value = Internal.text(value, 4096)
          @names += value.bytesize
          raise ArgumentError, 'Logical type name byte bound exceeded' if @names > 4096
          value
        end
      end
      private_constant :Budget
      module_function
      def typed(value, type)
        raise ArgumentError, 'Expected typed logical value' unless value.is_a?(type)
        value
      end
      def collection(values, type, maximum)
        raise ArgumentError, 'Invalid logical collection' unless values.is_a?(Array) && values.length <= maximum
        values.map { |value| typed(value, type) }.freeze
      end
      def cells(values)
        raise ArgumentError, 'Invalid logical cells' unless values.is_a?(Array) && values.length <= 65536
        values.map { |value| cell(value) }.freeze
      end
      def descriptor(value)
        raise ArgumentError, 'Expected logical descriptor' unless DESCRIPTORS.any? { |type| value.is_a?(type) }
        value
      end
      def cell(value)
        raise ArgumentError, 'Expected logical cell' unless CELLS.any? { |type| value.is_a?(type) }
        value
      end
      def object(value, fields)
        raise IncompatibleNative, 'Unexpected logical fields' unless value.is_a?(Hash) && value.keys.sort == fields.sort
        value
      end
      def variant(value)
        raise IncompatibleNative, 'Expected one logical variant' unless value.is_a?(Hash) && value.length == 1 && value.keys.first.is_a?(String)
        value.first
      end
      def type_wire(value, budget = Budget.new(256), depth = 0)
        descriptor(value); budget.enter(depth)
        element = ->(item) { { 'type' => type_wire(item.type, budget, depth + 1), 'nullable' => item.nullable } }
        case value
        when Scalar then { value.kind.to_s => {} }
        when Decimal
          precision = Internal.integer(value.precision, max: 38)
          { 'decimal' => { 'precision' => precision, 'scale' => Internal.integer(value.scale, min: 0, max: precision) } }
        when Timestamp
          raise ArgumentError, 'Unknown timestamp zone' unless %i[civil utc].include?(value.zone)
          { 'timestamp' => value.zone.to_s }
        when Structure, Union
          fields = value.fields.map { |field| { 'name' => budget.name(field.name), 'type' => type_wire(field.type, budget, depth + 1), 'nullable' => field.nullable, 'optional' => field.optional } }
          { value.is_a?(Structure) ? 'structure' : 'tagged_union' => fields }
        when List then { 'list' => element.call(value.element) }
        when ArrayType then { 'array' => { 'element' => element.call(value.element), 'length' => value.length } }
        when Map then { 'map' => { 'key' => type_wire(value.key, budget, depth + 1), 'value' => element.call(value.value) } }
        end
      end
      def type_from_wire(value, budget = Budget.new(256), depth = 0)
        budget.enter(depth); kind, payload = variant(value)
        if SCALARS.map(&:to_s).include?(kind)
          object(payload, []); return Scalar.new(kind: kind.to_sym)
        end
        element = lambda do |item|
          object(item, %w[type nullable]); Element.new(type: type_from_wire(item.fetch('type'), budget, depth + 1), nullable: item.fetch('nullable'))
        end
        case kind
        when 'decimal'
          object(payload, %w[precision scale]); precision = Internal.integer(payload.fetch('precision'), max: 38)
          Decimal.new(precision: precision, scale: Internal.integer(payload.fetch('scale'), min: 0, max: precision))
        when 'timestamp'
          raise IncompatibleNative, 'Unknown timestamp zone' unless %w[civil utc].include?(payload)
          Timestamp.new(zone: payload.to_sym)
        when 'structure', 'tagged_union'
          raise IncompatibleNative, 'Expected logical fields' unless payload.is_a?(Array)
          fields = payload.map do |field|
            object(field, %w[name type nullable optional]); Field.new(name: budget.name(field.fetch('name')), type: type_from_wire(field.fetch('type'), budget, depth + 1), nullable: field.fetch('nullable'), optional: field.fetch('optional'))
          end
          (kind == 'structure' ? Structure : Union).new(fields: fields)
        when 'list' then List.new(element: element.call(payload))
        when 'array'
          object(payload, %w[element length]); ArrayType.new(element: element.call(payload.fetch('element')), length: payload.fetch('length'))
        when 'map'
          object(payload, %w[key value]); Map.new(key: type_from_wire(payload.fetch('key'), budget, depth + 1), value: element.call(payload.fetch('value')))
        else raise IncompatibleNative, 'Unknown logical type'
        end
      end
      def integer(value, kind)
        low, high = case kind
                    when :signed, :decimal then [-(1 << 127), (1 << 127)-1]
                    when :unsigned then [0, (1 << 128)-1]
                    when :date_days then [-(1 << 31), (1 << 31)-1]
                    when :time_nanos then [0, U64_MAX]
                    when :timestamp_micros then [I64_MIN, I64_MAX]
                    else raise ArgumentError, 'Unknown exact logical integer'
                    end
        Internal.integer(value, min: low, max: high)
      end
      def exact(value, low, high)
        raise IncompatibleNative, 'Logical integer exceeds its textual bound' unless value.is_a?(String) && value.bytesize <= 40
        Value.wide(value, min: low, max: high)
      end
      def atom_wire(value, budget = Budget.new(65536))
        typed(value, Atom); kind, data = value.kind, value.value
        raise ArgumentError, 'Width belongs only to floats' if kind != :float && !value.width.nil?
        case kind
        when :signed, :unsigned, :decimal, :date_days, :time_nanos, :timestamp_micros then { kind.to_s => integer(data, kind).to_s }
        when :interval
          typed(data, Interval)
          { 'interval' => { 'months' => Internal.integer(data.months, min: -(1 << 31), max: (1 << 31)-1).to_s, 'days' => Internal.integer(data.days, min: -(1 << 31), max: (1 << 31)-1).to_s, 'nanos' => Internal.integer(data.nanos, min: I64_MIN, max: I64_MAX).to_s } }
        when :float
          raise ArgumentError, 'Expected finite float with explicit width' unless data.is_a?(Float) && data.finite? && [32, 64].include?(value.width)
          format = value.width == 32 ? 'e' : 'E'
          bits = [data].pack(format)
          raise ArgumentError, 'Float32 overflow' unless bits.unpack1(format).finite?
          budget.data(bits.bytesize); { 'float_bits' => bits.unpack1('H*') }
        when :boolean then { 'boolean' => Internal.boolean(data) }
        when :utf8
          budget.data(data.bytesize); { 'utf8' => data }
        when :binary, :uuid
          raise ArgumentError, 'Invalid UUID width' if kind == :uuid && data.bytesize != 16
          budget.data(data.bytesize); { kind.to_s => data.unpack1('H*') }
        else raise ArgumentError, 'Unknown logical atom'
        end
      end
      def atom_from_wire(value, budget = Budget.new(65536))
        kind, data = variant(value)
        case kind
        when 'signed', 'unsigned', 'decimal', 'date_days', 'time_nanos', 'timestamp_micros'
          number = exact(data, -(1 << 127), (1 << 128)-1)
          Atom.new(kind: kind.to_sym, value: integer(number, kind.to_sym))
        when 'interval'
          object(data, %w[months days nanos]); Atom.new(kind: :interval, value: Interval.new(months: exact(data.fetch('months'), -(1 << 31), (1 << 31)-1), days: exact(data.fetch('days'), -(1 << 31), (1 << 31)-1), nanos: exact(data.fetch('nanos'), I64_MIN, I64_MAX)))
        when 'float_bits', 'binary', 'uuid'
          bound = { 'float_bits' => 8, 'uuid' => 16 }.fetch(kind, 1024 * 1024)
          raw = Internal.unhex(data, bound); budget.data(raw.bytesize)
          if kind == 'float_bits'
            raise IncompatibleNative, 'Invalid logical float width' unless [4, 8].include?(raw.bytesize)
            number = raw.unpack1(raw.bytesize == 4 ? 'e' : 'E')
            raise IncompatibleNative, 'Nonfinite logical float' unless number.finite?
            Atom.new(kind: :float, value: number, width: raw.bytesize * 8)
          else
            raise IncompatibleNative, 'Invalid UUID width' if kind == 'uuid' && raw.bytesize != 16
            Atom.new(kind: kind.to_sym, value: raw)
          end
        when 'boolean' then Atom.new(kind: :boolean, value: Internal.boolean(data))
        when 'utf8'
          text = Internal.text(data, 1024 * 1024); budget.data(text.bytesize); Atom.new(kind: :utf8, value: text)
        else raise IncompatibleNative, 'Unknown logical atom'
        end
      end
      def cell_wire(value, budget = Budget.new(65536), depth = 0)
        cell(value); budget.enter(depth)
        case value
        when Missing then { 'missing' => {} }
        when Null then { 'null' => {} }
        when SourceTypeError then { 'type_error' => value.actual.to_s }
        when Conflict
          { 'conflict' => value.alternatives.map { |a| { 'counter' => a.counter.to_s, 'replica' => a.replica.to_s, 'value' => cell_wire(a.value, budget, depth) } } }
        when Present
          item = value.value
          data = case item
                 when Atom then { 'atom' => atom_wire(item, budget) }
                 when Sequence then { item.kind.to_s => item.cells.map { |child| cell_wire(child, budget, depth + 1) } }
                 when MapValue
                   { 'map' => item.entries.map { |entry| budget.enter(depth + 1); { 'key' => atom_wire(entry.key, budget), 'value' => cell_wire(entry.value, budget, depth + 1) } } }
                 when Tagged then { 'tagged_union' => { 'index' => item.index, 'value' => cell_wire(item.value, budget, depth + 1) } }
                 when Json
                   budget.data(item.json.bytesize); { 'json' => item.json }
                 end
          { 'value' => data }
        end
      end
      def cell_from_wire(value, budget = Budget.new(65536), depth = 0)
        budget.enter(depth); kind, payload = variant(value)
        case kind
        when 'missing', 'null'
          object(payload, []); return (kind == 'missing' ? Missing : Null).new
        when 'type_error'
          raise IncompatibleNative, 'Unknown source type' unless KINDS.map(&:to_s).include?(payload)
          return SourceTypeError.new(actual: payload.to_sym)
        when 'conflict'
          raise IncompatibleNative, 'Invalid conflict alternatives' unless payload.is_a?(Array) && payload.length.between?(2, 8)
          return Conflict.new(alternatives: payload.map do |item|
            object(item, %w[counter replica value]); Alternative.new(counter: exact(item.fetch('counter'), 1, U64_MAX), replica: exact(item.fetch('replica'), 1, U64_MAX), value: cell_from_wire(item.fetch('value'), budget, depth))
          end)
        when 'value' # Decode below using the same aggregate budget.
        else raise IncompatibleNative, 'Unknown logical cell'
        end
        kind, payload = variant(payload)
        result = case kind
                 when 'atom' then atom_from_wire(payload, budget)
                 when 'structure', 'list', 'array'
                   raise IncompatibleNative, 'Invalid logical sequence' unless payload.is_a?(Array)
                   Sequence.new(kind: kind.to_sym, cells: payload.map { |child| cell_from_wire(child, budget, depth + 1) })
                 when 'map'
                   raise IncompatibleNative, 'Invalid logical map' unless payload.is_a?(Array)
                   MapValue.new(entries: payload.map do |entry|
                     budget.enter(depth + 1); object(entry, %w[key value]); MapEntry.new(key: atom_from_wire(entry.fetch('key'), budget), value: cell_from_wire(entry.fetch('value'), budget, depth + 1))
                   end)
                 when 'tagged_union'
                   object(payload, %w[index value]); Tagged.new(index: payload.fetch('index'), value: cell_from_wire(payload.fetch('value'), budget, depth + 1))
                 when 'json'
                   text = Internal.text(payload, 1024 * 1024); budget.data(text.bytesize); Json.new(json: text)
                 else raise IncompatibleNative, 'Unknown logical value'
                 end
        Present.new(value: result)
      end
    end
  end
end
