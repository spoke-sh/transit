# frozen_string_literal: true
require 'transit/station'
require_relative 'sdk_examples/codecs'

module Transit
  module Examples
    TOTAL = Station::Key.new('total'.b, codec: U64)
    REQUEST = Station::Key.new('request'.b, codec: U64)
    OBSERVED = Station::Key.new('observed'.b, codec: U64)
    TABLE = Station::TableSchema.new(id: 1, value_type: :int64)
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
      def on_start(turn)
        turn.create_table(TABLE)
        turn.allow_query(@peer, TABLE, expected_revision: 0, allow: true)
      end
      def on_message(turn, input)
        case input
        in Station::Cast(value: Initialize) then nil
        in Station::Cast(value: Insert(key:, value:)) then turn.table(TABLE).insert(Station::Row.new(key: key, value: value))
        in Station::Call(value: Rows) then turn.start_query(TABLE, Station::QueryPlan.new(limit: (1 << 64) - 1))
        else raise HandlerError, 'Unexpected Table input'
        end
      end
    end
    class QueryRequester < Station::Handler
      def initialize(peer, &consume)
        raise ArgumentError, 'Supply an owned-segment consumer block' unless consume
        @peer, @consume = peer, consume
      end
      def on_message(turn, input)
        raise HandlerError, 'Unexpected query input' unless input.is_a?(Station::Cast) && input.value.is_a?(Start)
        raise HandlerError, 'Query already started' if turn.state.find(REQUEST)
        correlation = turn.call(@peer, Rows.new, codec: QUERY_SERVICE, wait: Station::WaitPolicy.untimed)
        turn.state.put(REQUEST, correlation)
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
