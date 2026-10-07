# frozen_string_literal: true
require_relative 'unified'
module Transit
  module Station
    class QueryPlan
      def initialize(plan)
        raise ArgumentError, 'Expected a general query plan' unless plan.is_a?(Unified::Plan)
        @data = JSON.generate(plan.wire).freeze
        freeze
      end
      def wire = JSON.parse(@data)
    end
    QueryJob = Data.define(:result, :correlation, :source)
    ResultManifest = Data.define(:result, :source, :destination, :correlation, :table, :policy_revision, :basis,
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
          table: Value.wide(value.fetch('table'), min: 1), policy_revision: Value.wide(value.fetch('policy_revision')),
          basis: TableBasis.new(resource: ResourceRef.new(realm: realm, resource: value.fetch('basis').fetch('resource')),
            revision: Internal.integer(value.fetch('basis').fetch('revision')), object: Value.wide(value.fetch('table'), min: 1), head: Value.digest(value.fetch('basis').fetch('head'))),
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
      def allow_query(peer, object, expected_revision:, allow:)
        pid = peer_id(peer)
        Internal.integer(object, max: U64_MAX); Internal.integer(expected_revision, min: 0, max: U64_MAX)
        Internal.boolean(allow)
        apply_native({ 'query_policy' => { 'peer' => pid, 'table' => object.to_s, 'expected_revision' => expected_revision.to_s, 'allow' => allow } })
        nil
      end
      def start_query(object, plan)
        check!
        Internal.integer(object, max: U64_MAX)
        raise ArgumentError, 'Expected QueryPlan' unless plan.is_a?(QueryPlan)
        value = apply_native({ 'query_start' => { 'id' => object.to_s, 'plan' => plan.wire } }).fetch('query')
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
