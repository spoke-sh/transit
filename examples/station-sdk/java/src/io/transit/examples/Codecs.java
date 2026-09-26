package io.transit.examples;

import io.transit.sdk.station.Codec;
import io.transit.examples.Messages.*;
import java.math.BigInteger;
import java.nio.*;
import java.util.*;

/** Application formats in the shared version-1 fixture, not Transit wire codecs. */
public final class Codecs {
    private Codecs() {}
    private static ByteBuffer output(char family, int length, int tag) {
        ByteBuffer buffer = ByteBuffer.allocate(length).order(ByteOrder.LITTLE_ENDIAN);
        buffer.put((byte) 'T').put((byte) 'S').put((byte) family).put((byte) 1);
        if (tag != 0) buffer.put((byte) tag);
        return buffer;
    }
    private static ByteBuffer input(byte[] bytes, char family, int minimum, int maximum) {
        if (bytes == null || bytes.length < minimum || bytes.length > maximum || bytes[0] != 'T' || bytes[1] != 'S' || bytes[2] != family || bytes[3] != 1) throw new IllegalArgumentException("Unsupported application format");
        ByteBuffer buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN); buffer.position(4); return buffer;
    }
    private static BigInteger unsigned(long bits) { return BigInteger.valueOf(bits).and(Messages.U64_MAX); }
    public static final Codec<BigInteger> U64 = new Codec<>() {
        @Override public String typeId() { return "transit.examples.u64"; }
        @Override public long version() { return 1; }
        @Override public int maxEncodedBytes() { return 12; }
        @Override public byte[] encode(BigInteger value) { return output('U', 12, 0).putLong(Messages.u64(value).longValue()).array(); }
        @Override public BigInteger decode(byte[] bytes) { return unsigned(input(bytes, 'U', 12, 12).getLong()); }
    };
    public static final class CounterCodec implements Codec<CounterMessage> {
        private final Set<Class<?>> allowed;
        public CounterCodec(Set<Class<?>> allowed) { this.allowed = Set.copyOf(allowed); }
        @Override public String typeId() { return "transit.examples.counter"; }
        @Override public long version() { return 1; }
        @Override public int maxEncodedBytes() { return 13; }
        private void role(CounterMessage value) { if (!allowed.contains(value.getClass())) throw new IllegalArgumentException("Unsupported counter role"); }
        @Override public byte[] encode(CounterMessage value) {
            role(value);
            return switch (value) {
                case Add add -> output('C', 13, 1).putLong(add.value().longValue()).array();
                case Read read -> output('C', 5, 2).array();
                case Start start -> output('C', 5, 3).array();
                case Total total -> output('C', 13, 4).putLong(total.value().longValue()).array();
            };
        }
        @Override public CounterMessage decode(byte[] bytes) {
            ByteBuffer buffer = input(bytes, 'C', 5, 13);
            CounterMessage value = switch (buffer.get()) {
                case 1 -> new Add(unsigned(buffer.getLong())); case 2 -> new Read();
                case 3 -> new Start(); case 4 -> new Total(unsigned(buffer.getLong()));
                default -> throw new IllegalArgumentException("Unknown counter message");
            };
            if (buffer.hasRemaining()) throw new IllegalArgumentException("Trailing counter bytes");
            role(value); return value;
        }
    }
    public static final class QueryCodec implements Codec<QueryMessage> {
        private final Set<Class<?>> allowed;
        public QueryCodec(Set<Class<?>> allowed) { this.allowed = Set.copyOf(allowed); }
        @Override public String typeId() { return "transit.examples.query"; }
        @Override public long version() { return 1; }
        @Override public int maxEncodedBytes() { return 22; }
        private void role(QueryMessage value) { if (!allowed.contains(value.getClass())) throw new IllegalArgumentException("Unsupported query role"); }
        @Override public byte[] encode(QueryMessage value) {
            role(value);
            return switch (value) {
                case Initialize initialize -> output('Q', 5, 1).array();
                case Rows rows -> output('Q', 5, 3).array();
                case Start start -> output('Q', 5, 4).array();
                case Insert insert -> {
                    ByteBuffer bytes = output('Q', insert.value() == null ? 14 : 22, 2).putLong(insert.key()).put((byte) (insert.value() == null ? 0 : 1));
                    if (insert.value() != null) bytes.putLong(insert.value());
                    yield bytes.array();
                }
            };
        }
        @Override public QueryMessage decode(byte[] bytes) {
            ByteBuffer buffer = input(bytes, 'Q', 5, 22);
            QueryMessage value = switch (buffer.get()) {
                case 1 -> new Initialize(); case 3 -> new Rows(); case 4 -> new Start();
                case 2 -> {
                    long key = buffer.getLong(); byte marker = buffer.get();
                    if (marker != 0 && marker != 1) throw new IllegalArgumentException("Invalid nullable marker");
                    yield new Insert(key, marker == 0 ? null : buffer.getLong());
                }
                default -> throw new IllegalArgumentException("Unknown query message");
            };
            if (buffer.hasRemaining()) throw new IllegalArgumentException("Trailing query bytes");
            role(value); return value;
        }
    }
    public static final Codec<CounterMessage> COUNTER = new CounterCodec(Set.of(Add.class, Read.class));
    public static final Codec<CounterMessage> REQUESTER = new CounterCodec(Set.of(Start.class, Total.class));
    public static final Codec<CounterMessage> REPLY = new CounterCodec(Set.of(Total.class));
    public static final Codec<QueryMessage> QUERY_SERVICE = new QueryCodec(Set.of(Initialize.class, Insert.class, Rows.class));
    public static final Codec<QueryMessage> QUERY_REQUESTER = new QueryCodec(Set.of(Start.class));
}
