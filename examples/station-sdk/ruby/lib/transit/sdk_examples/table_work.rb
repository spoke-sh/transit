# frozen_string_literal: true
require_relative 'codecs'
module Transit
  module Examples
    module TableWork
      MAX_INPUT = (1 << 53) - 1
      INITIAL = (1 << 64) - 1
      REJECTIONS = %i[none row_exists row_identity_exists null_not_allowed missing_required_field character_limit_exceeded overflow inexact].freeze
      Queue = Data.define(:head, :tail, :ready) do
        def initialize(head: 0, tail: 0, ready: false) = super
      end
      Work = Data.define(:next, :command)
      Outcome = Data.define(:state, :admitted, :completed, :matched, :changed, :rejection) do
        def initialize(state:, admitted:, completed:, matched: 0, changed: 0, rejection: 0) = super
      end
      class QueueCodec
        def type_id = 'transit.examples.table.queue'
        def version = 1
        def max_encoded_bytes = 21
        def encode(value)
          Examples.integer(value.head, 0, INITIAL); Examples.integer(value.tail, 0, MAX_INPUT)
          unless (value.head.zero? == value.tail.zero?) && (value.head == INITIAL || value.head <= value.tail) &&
              [true, false].include?(value.ready) && !(value.head == INITIAL && value.ready)
            raise ArgumentError, 'Invalid Table queue'
          end
          "TQM\x01".b + [value.head, value.tail, value.ready ? 1 : 0].pack('Q<Q<C')
        end
        def decode(bytes)
          TableWork.prefix(bytes, "TQM\x01".b, [21])
          raise ArgumentError, 'Invalid Table queue flag' unless bytes.getbyte(20) <= 1
          head, tail = bytes.byteslice(4, 16).unpack('Q<Q<')
          value = Queue.new(head: head, tail: tail, ready: bytes.getbyte(20) == 1)
          encode(value); value
        end
      end
      class WorkCodec
        def type_id = 'transit.examples.table.work'
        def version = 1
        def max_encoded_bytes = 34
        def encode(value)
          Examples.integer(value.next, 0, MAX_INPUT)
          raise ArgumentError, 'Invalid queued command' unless [Initialize, Insert, Update, Delete].include?(value.command.class)
          "TQW\x01".b + [value.next].pack('Q<') + QueryCodec.new.encode(value.command)
        end
        def decode(bytes)
          TableWork.prefix(bytes, "TQW\x01".b, [17, 25, 26, 34])
          value = Work.new(next: bytes.byteslice(4, 8).unpack1('Q<'), command: QueryCodec.new.decode(bytes.byteslice(12..)))
          encode(value); value
        end
      end
      class OutcomeCodec
        def type_id = 'transit.examples.table.outcome'
        def version = 1
        def max_encoded_bytes = 38
        def encode(value)
          Examples.integer(value.state, 0, 3); Examples.integer(value.admitted, 1, MAX_INPUT)
          Examples.integer(value.completed, value.admitted, MAX_INPUT); Examples.integer(value.matched, 0, INITIAL)
          Examples.integer(value.changed, 0, value.matched); Examples.integer(value.rejection, 0, REJECTIONS.length - 1)
          unless (value.state == 1 || (value.matched.zero? && value.changed.zero?)) && ((value.state == 2) == !value.rejection.zero?)
            raise ArgumentError, 'Invalid Table outcome'
          end
          "TQO\x01".b + [value.state, value.admitted, value.completed, value.matched, value.changed, value.rejection].pack('CQ<Q<Q<Q<C')
        end
        def decode(bytes)
          TableWork.prefix(bytes, "TQO\x01".b, [38])
          state, admitted, completed, matched, changed, rejection = bytes.byteslice(4..).unpack('CQ<Q<Q<Q<C')
          value = Outcome.new(state: state, admitted: admitted, completed: completed, matched: matched, changed: changed, rejection: rejection)
          encode(value); value
        end
      end
      def self.prefix(bytes, prefix, sizes)
        raise ArgumentError, 'Invalid Table application record' unless bytes.is_a?(String) && sizes.include?(bytes.bytesize) && bytes.start_with?(prefix)
      end
      QUEUE_CODEC = QueueCodec.new.freeze
      WORK_CODEC = WorkCodec.new.freeze
      OUTCOME_CODEC = OutcomeCodec.new.freeze
      QUEUE = Station::Key.new('table.queue'.b, codec: QUEUE_CODEC)
      def self.key(prefix, identity, codec)
        Examples.integer(identity, 1, INITIAL)
        Station::Key.new(format('%s%016x', prefix, identity).b, codec: codec)
      end
      def self.work_key(identity) = key('table.work.', identity, WORK_CODEC)
      def self.outcome_key(identity) = key('table.done.', identity, OUTCOME_CODEC)
    end
  end
end
