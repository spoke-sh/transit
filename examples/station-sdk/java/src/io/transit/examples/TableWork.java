package io.transit.examples;

import io.transit.sdk.station.Codec;
import io.transit.sdk.station.Key;
import io.transit.examples.Messages.*;
import java.math.BigInteger;
import java.nio.*;
import java.util.Set;

/** Compact application FIFO records; Table framework state remains native. */
public final class TableWork {
    private TableWork() {}
    public static final BigInteger MAX_INPUT = BigInteger.ONE.shiftLeft(53).subtract(BigInteger.ONE);
    public static final BigInteger INITIAL = Messages.U64_MAX;
    private static BigInteger bounded(BigInteger value, BigInteger low, BigInteger high) {
        if (value == null || value.compareTo(low) < 0 || value.compareTo(high) > 0) throw new IllegalArgumentException("Invalid Table record integer");
        return value;
    }
    public record Queue(BigInteger head, BigInteger tail, boolean ready) {
        public Queue {
            bounded(head, BigInteger.ZERO, INITIAL); bounded(tail, BigInteger.ZERO, MAX_INPUT);
            if ((head.signum() == 0) != (tail.signum() == 0) || (!head.equals(INITIAL) && head.compareTo(tail) > 0) || (head.equals(INITIAL) && ready)) throw new IllegalArgumentException("Invalid Table queue");
        }
        public Queue() { this(BigInteger.ZERO, BigInteger.ZERO, false); }
    }
    public record Work(BigInteger next, QueryMessage command) {
        public Work {
            bounded(next, BigInteger.ZERO, MAX_INPUT);
            if (!(command instanceof Initialize || command instanceof Insert || command instanceof Update || command instanceof Delete)) throw new IllegalArgumentException("Invalid queued command");
        }
    }
    public record Outcome(int state, long admitted, long completed, BigInteger matched, BigInteger changed, int rejection) {
        public Outcome {
            bounded(BigInteger.valueOf(admitted), BigInteger.ONE, MAX_INPUT);
            bounded(BigInteger.valueOf(completed), BigInteger.valueOf(admitted), MAX_INPUT);
            bounded(matched, BigInteger.ZERO, INITIAL); bounded(changed, BigInteger.ZERO, matched);
            if (state < 0 || state > 3 || rejection < 0 || rejection > 7 ||
                (state != 1 && (matched.signum() != 0 || changed.signum() != 0)) || (state == 2) != (rejection != 0)) throw new IllegalArgumentException("Invalid Table outcome");
        }
    }
    private static ByteBuffer output(char tag, int length) {
        return ByteBuffer.allocate(length).order(ByteOrder.LITTLE_ENDIAN).put((byte)'T').put((byte)'Q').put((byte)tag).put((byte)1);
    }
    private static ByteBuffer input(byte[] bytes, char tag, Set<Integer> sizes) {
        if (bytes == null || !sizes.contains(bytes.length) || bytes[0] != 'T' || bytes[1] != 'Q' || bytes[2] != tag || bytes[3] != 1) throw new IllegalArgumentException("Invalid Table application record");
        return ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).position(4);
    }
    private static BigInteger unsigned(long bits) { return BigInteger.valueOf(bits).and(INITIAL); }
    public static final Codec<Queue> QUEUE_CODEC = new Codec<>() {
        public String typeId() { return "transit.examples.table.queue"; }
        public long version() { return 1; }
        public int maxEncodedBytes() { return 21; }
        public byte[] encode(Queue value) { return output('M', 21).putLong(value.head().longValue()).putLong(value.tail().longValue()).put((byte)(value.ready() ? 1 : 0)).array(); }
        public Queue decode(byte[] bytes) {
            ByteBuffer buffer = input(bytes, 'M', Set.of(21)); BigInteger head = unsigned(buffer.getLong()), tail = unsigned(buffer.getLong()); byte ready = buffer.get();
            if (ready != 0 && ready != 1) throw new IllegalArgumentException("Invalid Table queue flag");
            return new Queue(head, tail, ready == 1);
        }
    };
    private static final Codec<QueryMessage> COMMAND = new Codecs.QueryCodec(Set.of(Initialize.class, Insert.class, Update.class, Delete.class));
    public static final Codec<Work> WORK_CODEC = new Codec<>() {
        public String typeId() { return "transit.examples.table.work"; }
        public long version() { return 1; }
        public int maxEncodedBytes() { return 34; }
        public byte[] encode(Work value) { byte[] command = COMMAND.encode(value.command()); return output('W', 12 + command.length).putLong(value.next().longValue()).put(command).array(); }
        public Work decode(byte[] bytes) {
            ByteBuffer buffer = input(bytes, 'W', Set.of(17, 25, 26, 34)); BigInteger next = unsigned(buffer.getLong()); byte[] command = new byte[buffer.remaining()]; buffer.get(command);
            return new Work(next, COMMAND.decode(command));
        }
    };
    public static final Codec<Outcome> OUTCOME_CODEC = new Codec<>() {
        public String typeId() { return "transit.examples.table.outcome"; }
        public long version() { return 1; }
        public int maxEncodedBytes() { return 38; }
        public byte[] encode(Outcome value) { return output('O', 38).put((byte)value.state()).putLong(value.admitted()).putLong(value.completed()).putLong(value.matched().longValue()).putLong(value.changed().longValue()).put((byte)value.rejection()).array(); }
        public Outcome decode(byte[] bytes) {
            ByteBuffer buffer = input(bytes, 'O', Set.of(38));
            return new Outcome(buffer.get(), buffer.getLong(), buffer.getLong(), unsigned(buffer.getLong()), unsigned(buffer.getLong()), buffer.get());
        }
    };
    public static final Key<Queue> QUEUE = new Key<>("table.queue", QUEUE_CODEC);
    private static <T> Key<T> key(String prefix, BigInteger identity, Codec<T> codec) {
        bounded(identity, BigInteger.ONE, INITIAL); return new Key<>(prefix + String.format("%016x", identity), codec);
    }
    public static Key<Work> workKey(BigInteger identity) { return key("table.work.", identity, WORK_CODEC); }
    public static Key<Outcome> outcomeKey(BigInteger identity) { return key("table.done.", identity, OUTCOME_CODEC); }
}
