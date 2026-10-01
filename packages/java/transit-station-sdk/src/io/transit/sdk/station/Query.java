package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.ProcessRef;
import io.transit.sdk.station.Types.*;
import static io.transit.client.internal.Values.*;
import java.math.BigInteger;
import java.util.*;

/** Native typed plans and bounded, owned original IPC. No foreign query engine. */
public final class Query {
    private Query() {}
    public enum Column { KEY, VALUE }
    public enum Comparison { EQ, NE, LT, LE, GT, GE }
    public enum Projection { BOTH, KEY, VALUE }
    public enum Aggregate { ROWS, COUNT, SUM, COUNT_VALUES }
    public enum CloseReason { CANCELLED, DENIED }
    public sealed interface Predicate permits All, IsNull, Compare {}
    public record All() implements Predicate {}
    public record IsNull(Column column) implements Predicate {
        public IsNull { Objects.requireNonNull(column); }
    }
    public record Compare<T>(Column column, Comparison comparison, Table.Cell<T> cell, T value) implements Predicate {
        public Compare {
            Objects.requireNonNull(column); Objects.requireNonNull(comparison); Objects.requireNonNull(cell);
            if (column == Column.KEY && cell != Table.INT64) throw new IllegalArgumentException("Table key comparison requires int64");
        }
        JsonObject wire(int bound) {
            return obj("compare", obj("column", column == Column.KEY ? 0 : 1, "op", comparison.name().toLowerCase(Locale.ROOT), "value", cell.encode(value, bound)));
        }
    }
    public record Plan(Projection projection, Aggregate aggregate, BigInteger limit, Predicate predicate) {
        public Plan { Objects.requireNonNull(projection); Objects.requireNonNull(aggregate); Objects.requireNonNull(predicate); if (limit != null) u64(limit); }
        public static Plan rows() { return new Plan(Projection.BOTH, Aggregate.ROWS, null, new All()); }
        JsonObject wire(int bound) {
            JsonObject selected = switch (predicate) {
                case All all -> obj("all", obj());
                case IsNull isNull -> obj("is_null", isNull.column() == Column.KEY ? 0 : 1);
                case Compare<?> compare -> compare.wire(bound);
            };
            return obj("projection", projection.name().toLowerCase(Locale.ROOT), "aggregate", aggregate.name().toLowerCase(Locale.ROOT),
                "limit", limit == null ? null : limit.toString(), "predicate", selected);
        }
    }
    public record Job(long result, BigInteger correlation, ReadVersion source) {}
    public record Manifest(long result, ProcessRef source, ProcessRef destination, BigInteger correlation, long table,
                           BigInteger policyRevision, Basis basis, Bytes sourceContract, Bytes plan, BigInteger segments, BigInteger byteCount,
                           BigInteger rows, Bytes chain, Bytes schema) {}
    public record IpcSegment(Manifest manifest, BigInteger ordinal, int rows, Bytes digest, Bytes bytes) {
        public byte[] ipc() { return bytes.copy(); }
        @Override public String toString() { return "IpcSegment[ordinal=" + ordinal + ", rows=" + rows + "]"; }
    }
    public static final class ResultReader {
        private final Turn turn;
        private final BigInteger correlation;
        ResultReader(Turn turn, BigInteger correlation) { this.turn = turn; this.correlation = correlation; }
        public BigInteger correlation() { return correlation; }
        private Manifest readManifest() {
            JsonObject value = object(turn.raw(obj("query_completed", correlation.toString())).get("manifest"));
            long realm = turn.process.realm();
            return new Manifest(number(value.get("result"), 1), new ProcessRef(realm, number(value.get("source"), 1)), new ProcessRef(realm, number(value.get("destination"), 1)),
                NativeValues.wide(value.get("correlation"), true), number(value.get("table"), 1), NativeValues.wide(value.get("policy_revision"), false), NativeValues.basis(value.get("basis"), realm), NativeValues.digest(object(value.get("basis")).get("contract")),
                NativeValues.digest(value.get("plan")), NativeValues.wide(value.get("segments"), false), NativeValues.wide(value.get("bytes"), false), NativeValues.wide(value.get("rows"), false),
                NativeValues.digest(value.get("chain")), NativeValues.digest(value.get("schema")));
        }
        public Manifest manifest() { return turn.access(true, this::readManifest); }
        public IpcSegment segment(BigInteger ordinal) {
            return turn.access(true, () -> {
                u64(ordinal); Manifest complete = readManifest();
                JsonObject value = object(turn.raw(obj("query_segment", obj("correlation", correlation.toString(), "ordinal", ordinal.toString()))).get("segment"));
                byte[] bytes = unhex(value.get("ipc"), turn.limit("query_segment_bytes"));
                BigInteger actual = NativeValues.wide(value.get("ordinal"), false);
                if (bytes.length != number(value.get("bytes"), 0) || number(value.get("result"), 1) != complete.result() || !actual.equals(ordinal)) throw incompatible("native-segment-identity");
                return new IpcSegment(complete, actual, Math.toIntExact(number(value.get("rows"), 0)), NativeValues.digest(value.get("digest")), new Bytes(bytes));
            });
        }
    }
}
