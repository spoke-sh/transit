package io.transit.examples;
import java.math.BigInteger;
public final class Messages {
    private Messages() {}
    public static final BigInteger U64_MAX = BigInteger.ONE.shiftLeft(64).subtract(BigInteger.ONE);
    public static BigInteger u64(BigInteger value) {
        if (value == null || value.signum() < 0 || value.compareTo(U64_MAX) > 0) throw new IllegalArgumentException("Expected application u64");
        return value;
    }
    public sealed interface CounterMessage permits Add, Read, Start, Total {}
    public sealed interface QueryMessage permits Initialize, Insert, Rows, Start {}
    public record Add(BigInteger value) implements CounterMessage { public Add { u64(value); } }
    public record Read() implements CounterMessage {}
    public record Start() implements CounterMessage, QueryMessage {}
    public record Total(BigInteger value) implements CounterMessage { public Total { u64(value); } }
    public record Initialize() implements QueryMessage {}
    public record Insert(long key, Long value) implements QueryMessage {}
    public record Rows() implements QueryMessage {}
}
