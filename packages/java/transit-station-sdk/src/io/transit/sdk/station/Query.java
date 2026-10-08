package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.ProcessRef;
import io.transit.client.ResourceRef;
import io.transit.sdk.station.Types.*;
import static io.transit.client.internal.Values.*;
import java.math.BigInteger;
import java.util.*;

/** Native typed plans and bounded, owned original IPC. No foreign query engine. */
public final class Query {
    private Query() {}
    public enum Comparison { EQ, NE, LT, LE, GT, GE }
    public enum Aggregate { ROWS, COUNT, SUM, COUNT_VALUES }
    public enum CloseReason { CANCELLED, DENIED }
    public static final class Plan {
        private final JsonObject value;
        public Plan(UnifiedQuery.Plan plan) { value = Objects.requireNonNull(plan).wire().deepCopy(); }
        JsonObject wire() { return value.deepCopy(); }
    }
    public record Job(long result, BigInteger correlation, ReadVersion source) {}
    public record Manifest(long result, ProcessRef source, ProcessRef destination, BigInteger correlation, BigInteger table,
                           BigInteger policyRevision, Table.Basis basis, Bytes plan, BigInteger segments, BigInteger byteCount,
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
                NativeValues.wide(value.get("correlation"), true), NativeValues.wide(value.get("table"), true), NativeValues.wide(value.get("policy_revision"), false),
                new Table.Basis(new ResourceRef(realm, number(object(value.get("basis")).get("resource"), 1)), number(object(value.get("basis")).get("revision"), 1), NativeValues.wide(value.get("table"), true), NativeValues.digest(object(value.get("basis")).get("head"))),
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
