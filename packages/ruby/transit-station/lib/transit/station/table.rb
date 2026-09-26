# frozen_string_literal: true
module Transit
  module Station
    TableSchema = Data.define(:id, :value_type, :key_name, :value_name) do
      def initialize(id:, value_type:, key_name: 'id', value_name: 'value')
        raise ArgumentError, 'Select a supported cell type' unless %i[int64 boolean utf8 binary].include?(value_type)
        super(id: Internal.integer(id, max: (1 << 32) - 1), value_type: value_type,
              key_name: Internal.text(key_name).freeze, value_name: Internal.text(value_name).freeze)
      end
    end
    Row = Data.define(:key, :value) do
      def initialize(key:, value:)
        super(key: Internal.integer(key, min: I64_MIN, max: I64_MAX), value: value.is_a?(String) ? value.dup.freeze : value)
      end
      def inspect = "#<Transit::Station::Row key=#{key}>"
    end
    module Value
      module_function
      def cell(value, type, bound)
        return { 'null' => {} } if value.nil?
        encoded = case type
                  when :int64 then Internal.integer(value, min: I64_MIN, max: I64_MAX).to_s
                  when :boolean then Internal.boolean(value)
                  when :utf8 then Internal.text(value, bound)
                  when :binary then Internal.bytes(value, bound).unpack1('H*')
                  else raise ArgumentError, 'Unsupported cell type'
                  end
        { type.to_s => encoded }
      end
      def cell_value(value, bound)
        return nil if value.key?('null')
        return wide(value.fetch('int64'), min: I64_MIN, max: I64_MAX) if value.key?('int64')
        return Internal.boolean(value.fetch('boolean')) if value.key?('boolean')
        return Internal.text(value.fetch('utf8'), bound).freeze if value.key?('utf8')
        return Internal.unhex(value.fetch('binary'), bound).freeze if value.key?('binary')
        raise IncompatibleNative, 'Unknown native cell'
      end
    end
    class Table
      attr_reader :schema, :basis
      def initialize(turn, schema, version = nil)
        raise ArgumentError, 'Expected TableSchema' unless schema.is_a?(TableSchema)
        @turn, @schema, @version = turn, schema, version
        request = { 'id' => schema.id }
        request['version'] = Value.version_wire(version) if version
        actual = apply({ 'table_schema' => request }, read: true).fetch('schema')
        unless [actual['key_name'], actual['value_name'], actual['value_type']] == [schema.key_name, schema.value_name, schema.value_type.to_s]
          raise HandlerError.new('Table schema differs from requested public type', code: 'TableSchemaChanged')
        end
        @basis = Value.basis(actual.fetch('basis'), turn.process.realm)
      end
      def get(key)
        request = { 'id' => schema.id, 'key' => Internal.integer(key, min: I64_MIN, max: I64_MAX).to_s }
        request['version'] = Value.version_wire(@version) if @version
        result = apply({ (@version ? 'version_table_get' : 'table_get') => request }, read: true).fetch('row')
        result.nil? ? nil : row(result)
      end
      def insert(row) = write(:insert, row)
      def update(row) = write(:update, row)
      def upsert(row) = write(:upsert, row)
      def delete(key)
        writable!
        apply({ 'table_delete' => { 'id' => schema.id, 'key' => Internal.integer(key, min: I64_MIN, max: I64_MAX).to_s } })
        nil
      end
      def page(cursor = nil)
        request = { 'id' => schema.id, 'cursor' => Value.cursor(cursor) }
        request['version'] = Value.version_wire(@version) if @version
        result = apply({ 'table_page' => request }, read: true).fetch('rows')
        Page.new(entries: result.fetch('rows').compact.map { |value| row(value) }.freeze, cursor: result['next']&.freeze,
                 basis: Value.basis(result.fetch('basis'), @turn.process.realm))
      end
      private
      def apply(action, read: false) = @turn.__send__(:apply_native, action, read: read)
      def bound = @turn.__send__(:caps).fetch('table_cell_bytes')
      def row(value) = Row.new(key: Value.wide(value.fetch('key'), min: I64_MIN, max: I64_MAX), value: Value.cell_value(value.fetch('value'), bound))
      def writable!
        @turn.__send__(:check!)
        raise HandlerError, 'Retained Tables are read-only' if @version
      end
      def write(mode, row)
        writable!
        raise ArgumentError, 'Expected Row' unless row.is_a?(Row)
        apply({ 'table_write' => { 'id' => schema.id, 'mode' => mode.to_s, 'row' => { 'key' => row.key.to_s, 'value' => Value.cell(row.value, schema.value_type, bound) } } })
        nil
      end
    end
  end
end
