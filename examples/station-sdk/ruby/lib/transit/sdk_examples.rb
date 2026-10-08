# frozen_string_literal: true
require 'transit/station'
require_relative 'sdk_examples/codecs'
require_relative 'sdk_examples/table_work'

module Transit
  module Examples
    TOTAL = Station::Key.new('total'.b, codec: U64)
    REQUEST = Station::Key.new('request'.b, codec: U64)
    OBSERVED = Station::Key.new('observed'.b, codec: U64)
    def self.signed(value) = Station::Logical::Present.new(value: Station::Logical::Atom.new(kind: :signed, value: value))
    TABLE = Station::TableSchema.new(object: 1, revision: 1, next_column: 5, columns: [
      Station::Catalog::Column.new(id: 1, name: 'id', type: Station::Logical::Scalar.new(kind: :int64), nullable: false),
      Station::Catalog::Column.new(id: 2, name: 'value', type: Station::Logical::Scalar.new(kind: :int64)),
      Station::Catalog::Column.new(id: 3, name: 'label', type: Station::Logical::Scalar.new(kind: :utf8), nullable: false,
        default: Station::Logical::Present.new(value: Station::Logical::Atom.new(kind: :utf8, value: 'example'))),
      Station::Catalog::Column.new(id: 4, name: 'tags', type: Station::Logical::List.new(element: Station::Logical::Element.new(type: Station::Logical::Scalar.new(kind: :int64))), nullable: false,
        default: Station::Logical::Present.new(value: Station::Logical::Sequence.new(kind: :list, cells: [signed(1), signed(2)])))
    ], primary_key: [1])
    TABLE_LIMITS = Station::Catalog::TableLimits.new(record_bytes: 65536, staging_bytes: 8388608, staging_records: 1024)
    NOT_READY = Station::Key.new('not-ready'.b, codec: U64)
    class Counter < Station::Handler
      def on_start(turn) = turn.state.put(TOTAL, 0)
      def on_message(turn, input)
        case input
        in Station::Cast(value: Add(value:))
          turn.state.put(TOTAL, Examples.integer(turn.state.require(TOTAL) + value, 0, (1 << 64) - 1))
        in Station::Call(value: Read)
          turn.reply(Total.new(value: turn.state.require(TOTAL)), codec: REPLY)
        else raise HandlerError, 'Unexpected counter input'
        end
      end
    end
    class Requester < Station::Handler
      def initialize(peer) = @peer = peer
      def on_message(turn, input)
        case input
        in Station::Cast(value: Start)
          raise HandlerError, 'Call already started' if turn.state.find(REQUEST)
          correlation = turn.call(@peer, Read.new, codec: COUNTER, wait: Station::WaitPolicy.untimed)
          turn.state.put(REQUEST, correlation)
        in Station::Reply(value: Total(value:))
          turn.require_reply(input, peer: @peer, correlation: turn.state.require(REQUEST))
          turn.state.put(OBSERVED, value)
        else raise HandlerError, 'Unexpected requester input'
        end
      end
    end
    class TableService < Station::Handler
      def initialize(peer) = @peer = peer
      def on_message(turn, input)
        command = input.value
        if input.is_a?(Station::Cast) && [Initialize, Insert, Update, Delete].include?(command.class)
          enqueue(turn, input.position, command)
        elsif input.is_a?(Station::Cast) && command.is_a?(Advance)
          unless input.origin.is_a?(Station::ProcessOrigin) && input.origin.process == turn.process
            raise HandlerError, 'Table continuation requires its recorded self output'
          end
          drive(turn)
        elsif input.is_a?(Station::Call) && command.is_a?(Rows)
          pending = queue(turn)
          if !pending.ready || !pending.head.zero?
            turn.reply(NotReady.new, codec: QUERY_REPLY)
          else
            turn.start_query(TABLE.object, Station::QueryPlan.new(Station::Unified::Plan.new(projection: [0, 1, 2, 3], limit: TableWork::INITIAL)))
          end
        else raise HandlerError, 'Unexpected Table input'
        end
      end
      private
      def queue(turn) = turn.state.find(TableWork::QUEUE)&.value || TableWork::Queue.new
      def wake(turn) = turn.cast(turn.process, Advance.new, codec: QUERY_SERVICE)
      def enqueue(turn, identity, command)
        Examples.integer(identity, 1, TableWork::MAX_INPUT)
        pending = queue(turn)
        key = TableWork.work_key(identity)
        if turn.state.find(key) || turn.state.find(TableWork.outcome_key(identity))
          raise HandlerError, 'Table input identity reused'
        end
        head = identity
        unless pending.tail.zero?
          raise HandlerError, 'Table queue order changed' unless identity > pending.tail
          tail = turn.state.require(TableWork.work_key(pending.tail))
          raise HandlerError, 'Invalid Table queue tail' unless tail.next.zero?
          turn.state.put(TableWork.work_key(pending.tail), TableWork::Work.new(next: identity, command: tail.command))
          head = pending.head
        else
          if !pending.ready && !command.is_a?(Initialize)
            turn.state.put(TableWork.work_key(TableWork::INITIAL), TableWork::Work.new(next: identity, command: Initialize.new))
            head = TableWork::INITIAL
          end
        end
        turn.state.put(key, TableWork::Work.new(next: 0, command: command))
        turn.state.put(TableWork::QUEUE, TableWork::Queue.new(head: head, tail: identity, ready: pending.ready))
        wake(turn) if pending.head.zero?
      end
      def drive(turn)
        pending = queue(turn)
        return if pending.head.zero?
        work = turn.state.require(TableWork.work_key(pending.head))
        unless work.next.zero? == (pending.head == pending.tail)
          raise HandlerError, 'Invalid Table queue link'
        end
        if !work.next.zero? && pending.head != TableWork::INITIAL && work.next <= pending.head
          raise HandlerError, 'Invalid Table queue order'
        end
        command = work.command
        status = if command.is_a?(Initialize)
                   turn.create_table(TABLE, TABLE_LIMITS)
                 else
                   raise HandlerError, 'Table queue is not initialized' unless pending.ready && pending.head != TableWork::INITIAL
                   predicate = [Station::Catalog::Comparison.new(column: 1, op: :eq, value: Station::Logical::Atom.new(kind: :signed, value: command.key))]
                   mutation = if command.is_a?(Delete)
                                Station::Catalog::Delete.new(predicate: predicate)
                              else
                                value = command.value.nil? ? Station::Logical::Null.new : Examples.signed(command.value)
                                if command.is_a?(Insert)
                                  Station::Catalog::Insert.new(rows: [[Station::Catalog::Assignment.new(column: 1, value: Examples.signed(command.key)), Station::Catalog::Assignment.new(column: 2, value: value)]])
                                else
                                  Station::Catalog::Update.new(assignments: [Station::Catalog::Assignment.new(column: 2, value: value)], predicate: predicate)
                                end
                              end
                   Station::TableMutation.prepare(resource: turn.resource, principal: 0, operation: pending.head, schema: TABLE, mutation: mutation).step(turn)
                 end
        return wake(turn) if status.state == :building
        initialize = status.is_a?(Station::TableCreation)
        return wake(turn) if turn.budgets.mutations < 3 + (initialize && !pending.ready ? 1 : 0)
        raise HandlerError, 'Missing Table completion' unless status.completed_input
        if initialize
          raise HandlerError, 'Table initialization failed' unless status.state == :applied
          outcome = TableWork::Outcome.new(state: 0, admitted: status.admitted_input, completed: status.completed_input)
          turn.allow_query(@peer, TABLE.object, expected_revision: 0, allow: true) unless pending.ready
        else
          outcome = TableWork::Outcome.new(state: {applied: 1, rejected: 2, cancelled: 3}.fetch(status.state),
            admitted: status.admitted_input, completed: status.completed_input, matched: status.counts&.matched || 0,
            changed: status.counts&.changed || 0, rejection: TableWork::REJECTIONS.index(status.rejection))
        end
        turn.state.put(TableWork.outcome_key(pending.head), outcome)
        turn.state.delete(TableWork.work_key(pending.head))
        turn.state.put(TableWork::QUEUE, TableWork::Queue.new(head: work.next, tail: work.next.zero? ? 0 : pending.tail, ready: pending.ready || initialize))
        wake(turn) unless work.next.zero?
      end
    end
    class QueryRequester < Station::Handler
      def initialize(peer, &consume)
        raise ArgumentError, 'Supply an owned-segment consumer block' unless consume
        @peer, @consume = peer, consume
      end
      def on_message(turn, input)
        if input.is_a?(Station::Reply) && input.value.is_a?(NotReady)
          turn.require_reply(input, peer: @peer, correlation: turn.state.require(REQUEST))
          turn.state.put(NOT_READY, input.correlation)
          return
        end
        raise HandlerError, 'Unexpected query input' unless input.is_a?(Station::Cast) && input.value.is_a?(Start)
        previous = turn.state.find(REQUEST)
        not_ready = turn.state.find(NOT_READY)
        raise HandlerError, 'Query already started' if previous && not_ready&.value != previous.value
        correlation = turn.call(@peer, Rows.new, codec: QUERY_SERVICE, wait: Station::WaitPolicy.untimed)
        turn.state.put(REQUEST, correlation)
        turn.state.delete(NOT_READY) if not_ready
      end
      def on_result(turn, complete)
        reader = turn.result(complete.correlation)
        manifest = reader.manifest
        unless manifest.source == @peer && manifest.correlation == turn.state.require(REQUEST)
          raise HandlerError, 'Unexpected query provenance'
        end
        # Application callback effects need their own replay/idempotency policy.
        manifest.segments.times { |ordinal| @consume.call(reader.segment(ordinal)) }
        turn.state.put(OBSERVED, manifest.rows)
      end
    end
  end
end
