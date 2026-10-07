# frozen_string_literal: true
module Transit
  module Examples
    def self.integer(value, min, max)
      raise ArgumentError, 'Integer outside application format' unless value.is_a?(Integer) && value.between?(min, max)
      value
    end
    Add = Data.define(:value) do
      def initialize(value:) = super(value: Examples.integer(value, 0, (1 << 64) - 1))
    end
    Total = Data.define(:value) do
      def initialize(value:) = super(value: Examples.integer(value, 0, (1 << 64) - 1))
    end
    Read = Data.define
    Start = Data.define
    Initialize = Data.define
    Rows = Data.define
    Advance = Data.define
    NotReady = Data.define
    Insert = Data.define(:key, :value) do
      def initialize(key:, value:)
        super(key: Examples.integer(key, -(1 << 63), (1 << 63) - 1), value: value.nil? ? nil : Examples.integer(value, -(1 << 63), (1 << 63) - 1))
      end
    end
    Update = Data.define(:key, :value) do
      def initialize(key:, value:)
        super(key: Examples.integer(key, -(1 << 63), (1 << 63) - 1), value: value.nil? ? nil : Examples.integer(value, -(1 << 63), (1 << 63) - 1))
      end
    end
    Delete = Data.define(:key) do
      def initialize(key:) = super(key: Examples.integer(key, -(1 << 63), (1 << 63) - 1))
    end
    class CounterCodec
      def type_id = 'transit.examples.counter'
      def version = 1
      def max_encoded_bytes = 13
      def initialize(only: [Add, Read, Start, Total])
        @only = only.dup.freeze
        freeze
      end
      def encode(value)
        raise ArgumentError, 'Unsupported counter role' unless @only.include?(value.class)
        tag = { Add => 1, Read => 2, Start => 3, Total => 4 }.fetch(value.class)
        bytes = "TSC\x01".b + [tag].pack('C')
        bytes << [Examples.integer(value.value, 0, (1 << 64) - 1)].pack('Q<') if [1, 4].include?(tag)
        bytes
      end
      def decode(bytes)
        raise ArgumentError, 'Unsupported counter format' unless bytes.is_a?(String) && bytes.bytesize >= 5 && bytes.start_with?("TSC\x01".b)
        tag = bytes.getbyte(4)
        value = if [1, 4].include?(tag) && bytes.bytesize == 13
                  (tag == 1 ? Add : Total).new(value: bytes.byteslice(5, 8).unpack1('Q<'))
                elsif tag == 2 && bytes.bytesize == 5 then Read.new
                elsif tag == 3 && bytes.bytesize == 5 then Start.new
                else raise ArgumentError, 'Malformed counter message'
                end
        raise ArgumentError, 'Unsupported counter role' unless @only.include?(value.class)
        value
      end
    end
    class U64Codec
      def type_id = 'transit.examples.u64'
      def version = 1
      def max_encoded_bytes = 12
      def encode(value) = "TSU\x01".b + [Examples.integer(value, 0, (1 << 64) - 1)].pack('Q<')
      def decode(bytes)
        raise ArgumentError, 'Invalid u64 state' unless bytes.is_a?(String) && bytes.bytesize == 12 && bytes.start_with?("TSU\x01".b)
        bytes.byteslice(4, 8).unpack1('Q<')
      end
    end
    class QueryCodec
      def type_id = 'transit.examples.query'
      def version = 1
      def max_encoded_bytes = 22
      def initialize(only: [Initialize, Insert, Rows, Start, Advance, NotReady, Update, Delete])
        @only = only.dup.freeze
        freeze
      end
      def encode(value)
        raise ArgumentError, 'Unsupported query role' unless @only.include?(value.class)
        tag = { Initialize => 1, Insert => 2, Rows => 3, Start => 4, Advance => 5, NotReady => 6, Update => 7, Delete => 8 }.fetch(value.class)
        bytes = "TSQ\x01".b + [tag].pack('C')
        bytes << [Examples.integer(value.key, -(1 << 63), (1 << 63) - 1)].pack('q<') if tag == 8
        if [2, 7].include?(tag)
          bytes << [Examples.integer(value.key, -(1 << 63), (1 << 63) - 1)].pack('q<')
          bytes << [value.value.nil? ? 0 : 1].pack('C')
          bytes << [Examples.integer(value.value, -(1 << 63), (1 << 63) - 1)].pack('q<') unless value.value.nil?
        end
        bytes
      end
      def decode(bytes)
        raise ArgumentError, 'Unsupported query format' unless bytes.is_a?(String) && bytes.bytesize >= 5 && bytes.start_with?("TSQ\x01".b)
        tag = bytes.getbyte(4)
        value = if [2, 7].include?(tag) && [14, 22].include?(bytes.bytesize)
                  marker = bytes.getbyte(13)
                  raise ArgumentError, 'Malformed nullable cell' unless (marker.zero? && bytes.bytesize == 14) || (marker == 1 && bytes.bytesize == 22)
                  (tag == 2 ? Insert : Update).new(key: bytes.byteslice(5, 8).unpack1('q<'), value: marker.zero? ? nil : bytes.byteslice(14, 8).unpack1('q<'))
                elsif tag == 8 && bytes.bytesize == 13 then Delete.new(key: bytes.byteslice(5, 8).unpack1('q<'))
                elsif bytes.bytesize == 5 && [1, 3, 4, 5, 6].include?(tag)
                  { 1 => Initialize, 3 => Rows, 4 => Start, 5 => Advance, 6 => NotReady }.fetch(tag).new
                else raise ArgumentError, 'Malformed query message'
                end
        raise ArgumentError, 'Unsupported query role' unless @only.include?(value.class)
        value
      end
    end
    COUNTER = CounterCodec.new(only: [Add, Read])
    REQUESTER = CounterCodec.new(only: [Start, Total])
    REPLY = CounterCodec.new(only: [Total])
    QUERY_SERVICE = QueryCodec.new(only: [Initialize, Insert, Rows, Advance, Update, Delete])
    QUERY_REQUESTER = QueryCodec.new(only: [Start, NotReady])
    QUERY_REPLY = QueryCodec.new(only: [NotReady])
    U64 = U64Codec.new.freeze
  end
end
