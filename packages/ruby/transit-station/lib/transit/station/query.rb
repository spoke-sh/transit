# frozen_string_literal: true
module Transit
  module Station
    Predicate = Data.define(:column, :comparison, :value, :value_type) do
      def initialize(column:, comparison: nil, value: nil, value_type: :int64)
        raise ArgumentError, 'Select key or value' unless %i[key value].include?(column)
        raise ArgumentError, 'Select a comparison or null predicate' unless comparison.nil? || %i[eq ne lt le gt ge].include?(comparison)
        raise ArgumentError, 'Null predicate cannot carry a value' if comparison.nil? && !value.nil?
        raise ArgumentError, 'Select a cell type' unless %i[int64 boolean utf8 binary].include?(value_type)
        super(column: column, comparison: comparison, value: value.is_a?(String) ? value.dup.freeze : value, value_type: value_type)
      end
    end
    QueryPlan = Data.define(:projection, :aggregate, :limit, :predicate) do
      def initialize(projection: :both, aggregate: :rows, limit: nil, predicate: nil)
        raise ArgumentError, 'Select a supported projection/aggregate' unless %i[both key value].include?(projection) && %i[rows count sum].include?(aggregate)
        Internal.integer(limit, min: 0, max: U64_MAX) unless limit.nil?
        raise ArgumentError, 'Expected Predicate' unless predicate.nil? || predicate.is_a?(Predicate)
        super
      end
    end
    QueryJob = Data.define(:result, :correlation, :source)
    ResultManifest = Data.define(:result, :source, :destination, :correlation, :table, :policy_revision, :basis, :source_contract,
                                 :plan, :segments, :byte_count, :rows, :chain, :schema)
    class IpcSegment
      attr_reader :manifest, :ordinal, :rows, :digest
      def initialize(manifest:, ordinal:, rows:, digest:, ipc:, bound:)
        @manifest, @ordinal, @rows, @digest = manifest, ordinal, rows, digest
        @ipc = Internal.bytes(ipc, bound).freeze
        freeze
      end
      def ipc = @ipc.dup
      def inspect = "#<Transit::Station::IpcSegment ordinal=#{ordinal} rows=#{rows}>"
    end
    class ResultReader
      attr_reader :correlation
      def initialize(turn, correlation)
        @turn, @correlation = turn, Internal.integer(correlation, max: U64_MAX)
      end
      def manifest
        @turn.__send__(:operation, read: true) { read_manifest }
      end
      private def read_manifest
        value = apply({ 'query_completed' => correlation.to_s }).fetch('manifest')
        realm = @turn.process.realm
        ResultManifest.new(result: value.fetch('result'), source: ProcessRef.new(realm: realm, pid: value.fetch('source')),
          destination: ProcessRef.new(realm: realm, pid: value.fetch('destination')), correlation: Value.wide(value.fetch('correlation'), min: 1),
          table: value.fetch('table'), policy_revision: Value.wide(value.fetch('policy_revision')), basis: Value.basis(value.fetch('basis'), realm), source_contract: Value.digest(value.fetch('basis').fetch('contract')),
          plan: Value.digest(value.fetch('plan')), segments: Value.wide(value.fetch('segments')), byte_count: Value.wide(value.fetch('bytes')),
          rows: Value.wide(value.fetch('rows')), chain: Value.digest(value.fetch('chain')), schema: Value.digest(value.fetch('schema')))
      end
      def segment(ordinal)
        @turn.__send__(:operation, read: true) do
          Internal.integer(ordinal, min: 0, max: U64_MAX)
          complete = read_manifest
          value = apply({ 'query_segment' => { 'correlation' => correlation.to_s, 'ordinal' => ordinal.to_s } }).fetch('segment')
          bound = @turn.__send__(:caps).fetch('query_segment_bytes')
          ipc = Internal.unhex(value.fetch('ipc'), bound)
          raise IncompatibleNative, 'Native IPC length mismatch' unless ipc.bytesize == value.fetch('bytes')
          IpcSegment.new(manifest: complete, ordinal: Value.wide(value.fetch('ordinal')), rows: value.fetch('rows'),
                        digest: Value.digest(value.fetch('digest')), ipc: ipc, bound: bound)
        end
      end
      private
      def apply(action) = @turn.__send__(:raw_native, action)
    end
    class Turn
      def allow_query(peer, table, expected_revision:, allow:)
        pid = peer_id(peer)
        raise ArgumentError, 'Expected TableSchema' unless table.is_a?(TableSchema)
        Internal.integer(expected_revision, min: 0)
        Internal.boolean(allow)
        apply_native({ 'query_policy' => { 'peer' => pid, 'table' => table.id, 'expected_revision' => expected_revision, 'allow' => allow } })
        nil
      end
      def start_query(schema, plan)
        check!
        raise ArgumentError, 'Expected QueryPlan' unless plan.is_a?(QueryPlan)
        table(schema)
        predicate = { 'all' => {} }
        if (selected = plan.predicate)
          column = selected.column == :key ? 0 : 1
          predicate = if selected.comparison.nil?
                        { 'is_null' => column }
                      else
                        { 'compare' => { 'column' => column, 'op' => selected.comparison.to_s,
                          'value' => Value.cell(selected.value, selected.value_type, caps.fetch('table_cell_bytes')) } }
                      end
        end
        value = apply_native({ 'query_start' => { 'id' => schema.id, 'plan' => { 'projection' => plan.projection.to_s,
          'aggregate' => plan.aggregate.to_s, 'limit' => plan.limit&.to_s, 'predicate' => predicate } } }).fetch('query')
        QueryJob.new(result: value.fetch('result'), correlation: Value.wide(value.fetch('correlation'), min: 1), source: Value.version(value.fetch('source')))
      end
      def close_query(result, reason: :cancelled)
        raise ArgumentError, 'Select cancelled or denied closure' unless %i[cancelled denied].include?(reason)
        apply_native({ 'query_close' => { 'result' => Internal.integer(result), 'reason' => reason.to_s } })
        nil
      end
      def result(correlation)
        check!
        ResultReader.new(self, correlation)
      end
    end
  end
end
