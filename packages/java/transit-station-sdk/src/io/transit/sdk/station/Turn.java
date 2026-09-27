package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import io.transit.sdk.station.Types.*;
import static io.transit.client.internal.Values.*;
import java.math.BigInteger;
import java.util.*;
import java.util.function.Supplier;

/** A scoped handler capability. Saving a handle never extends its lifetime. */
public final class Turn {
    final Bridge bridge;
    final JsonObject event;
    final ProcessRef process;
    final ResourceRef resource;
    final long scope;
    final StopToken stop;
    private final Thread owner = Thread.currentThread();
    private volatile boolean active = true;
    private boolean busy;
    TransitException poison;
    Turn(Bridge bridge, JsonObject event, ProcessRef process, StopToken stop) {
        this.bridge = bridge; this.event = event; this.process = process; this.stop = stop;
        scope = number(event.get("scope"), 1);
        resource = new ResourceRef(process.realm(), number(event.get("resource"), 1));
    }
    void endScope() { active = false; }
    void check() {
        if (!active) throw new TransitException(TransitException.Kind.TURN_EXPIRED, "turn-scope");
        if (Thread.currentThread() != owner || busy) throw new TransitException(TransitException.Kind.BUSY, "turn-owner");
        if (stop.stopped()) throw new TransitException(TransitException.Kind.CLOSED, "turn-stop");
        if (poison != null) throw poison;
    }
    <T> T access(boolean read, Supplier<T> work) {
        check(); busy = true;
        try { return work.get(); }
        catch (Throwable failure) {
            TransitException error = NativeValues.normalize(failure, read ? "read" : "turn-operation");
            if (read && poison == null) poison = error;
            throw error;
        } finally { busy = false; }
    }
    JsonObject raw(JsonObject action) { return bridge.apply(scope, action); }
    int limit(String name) { return bridge.limit(name); }
    long peer(ProcessRef peer) {
        Objects.requireNonNull(peer);
        if (peer.realm() != process.realm()) throw new IllegalArgumentException("Peer must be in this realm");
        return peer.pid();
    }
    public ProcessRef process() { check(); return process; }
    public ResourceRef resource() { check(); return resource; }
    public long resourceRevision() { check(); return number(event.get("resource_revision"), 0); }
    public State state() { check(); return new State(this, null); }
    public Budgets budgets() {
        return access(false, () -> {
            JsonObject budget = object(raw(obj("budgets", obj())).get("budgets"));
            return new Budgets(count(budget, "mutations"), count(budget, "outputs"), count(budget, "views"),
                count(budget, "retained_reads"), count(budget, "retains"), count(budget, "releases"));
        });
    }
    private static int count(JsonObject object, String name) { return Math.toIntExact(number(object.get(name), 0)); }
    public <T> void cast(ProcessRef peer, T value, Codec<T> codec) {
        access(false, () -> {
            long pid = peer(peer);
            byte[] bytes = NativeValues.encode(codec, value, limit("message_bytes"));
            raw(obj("cast", obj("pid", pid, "value", HexFormat.of().formatHex(bytes)))); return null;
        });
    }
    public <T> BigInteger call(ProcessRef peer, T value, Codec<T> codec, WaitPolicy wait) {
        return access(false, () -> {
            long pid = peer(peer); Objects.requireNonNull(wait);
            Long observer = wait.observer() == null ? null : peer(wait.observer());
            byte[] bytes = NativeValues.encode(codec, value, limit("message_bytes"));
            return NativeValues.wide(raw(obj("call", obj("pid", pid, "value", HexFormat.of().formatHex(bytes),
                "deadline_ms", wait.deadlineMillis(), "observer", observer))).get("correlation"), true);
        });
    }
    public <T> void reply(T value, Codec<T> codec) {
        access(false, () -> {
            byte[] bytes = NativeValues.encode(codec, value, limit("message_bytes"));
            raw(obj("reply", HexFormat.of().formatHex(bytes))); return null;
        });
    }
    public void requireReply(Reply<?> reply, ProcessRef peer, BigInteger correlation) {
        access(false, () -> {
            long pid = peer(peer); u64(correlation); Objects.requireNonNull(reply);
            JsonObject input = object(event.get("input"));
            Origin origin = NativeValues.origin(input.get("origin"), process.realm());
            if (!string(input.get("kind")).equals("reply") || !(origin instanceof ProcessOrigin source) || source.process().pid() != pid ||
                !NativeValues.wide(input.get("correlation"), true).equals(correlation) || reply.position() != number(input.get("position"), 1) || !reply.correlation().equals(correlation)) {
                throw NativeValues.handlerError("reply-identity");
            }
            return null;
        });
    }
    public boolean cancelCall(BigInteger correlation) {
        return access(false, () -> bool(raw(obj("cancel", positive(correlation).toString())).get("cancelled")));
    }
    private void httpRequest(Http.Prepared request) {
        Objects.requireNonNull(request);
        if (!resource.equals(request.resource())) throw new IllegalArgumentException("HTTP request must use this writable resource");
        bridge.httpCapability("http_requests");
    }
    public boolean stageHttp(Http.Prepared request) {
        return access(false, () -> {
            httpRequest(request);
            return bool(raw(obj("http_stage", obj("reference", request.referenceHex(), "metadata", request.metadataHex(), "body", request.bodyHex()))).get("staged"));
        });
    }
    public BigInteger callHttp(ProcessRef connector, Http.Prepared request) {
        return access(false, () -> {
            httpRequest(request);
            return NativeValues.wide(raw(obj("http_call", obj("pid", peer(connector), "reference", request.referenceHex()))).get("correlation"), true);
        });
    }
    /** Request durable hold disposal; authenticate the correlated Http.Released reply. */
    public BigInteger releaseHttp(ProcessRef connector, ResourceRef capture, BigInteger exchange) {
        return access(false, () -> {
            Objects.requireNonNull(capture); positive(exchange);
            if (capture.realm() != resource.realm()) throw new IllegalArgumentException("HTTP capture must belong to this realm");
            bridge.httpCapability("http_release");
            return NativeValues.wide(raw(obj("http_release", obj("pid", peer(connector), "resource", capture.resource(), "exchange", exchange.toString()))).get("correlation"), true);
        });
    }
    static BigInteger positive(BigInteger value) { u64(value); if (value.signum() == 0) throw new IllegalArgumentException("Correlation must be nonzero"); return value; }
    /** Submit an explicit linked attempt; the service decides current admission. */
    public BigInteger followupHttp(ProcessRef connector, Http.Outcome parent, Http.FollowupReason reason, Http.Prepared request) {
        return access(false, () -> {
            Objects.requireNonNull(parent); Objects.requireNonNull(reason); httpRequest(request);
            if (parent.resource().realm() != resource.realm()) throw new IllegalArgumentException("HTTP parent must belong to this realm");
            bridge.httpCapability("http_followup");
            return NativeValues.wide(raw(obj("http_followup", obj("pid", peer(connector), "resource", parent.resource().resource(),
                "parent", parent.exchange().toString(), "reason", reason.name().toLowerCase(Locale.ROOT), "reference", request.referenceHex()))).get("correlation"), true);
        });
    }
    public <T> Table<T> table(Table.Schema<T> schema) { return access(true, () -> Table.open(this, schema, null)); }
    public <T> Table<T> createTable(Table.Schema<T> schema) {
        access(false, () -> {
            Objects.requireNonNull(schema);
            text(schema.keyName(), limit("table_name_bytes")); text(schema.valueName(), limit("table_name_bytes"));
            raw(obj("table_create", obj("id", schema.id(), "key_name", schema.keyName(), "value_name", schema.valueName(), "value_type", schema.cell().wireName())));
            return null;
        });
        return table(schema);
    }
    public ReadVersion retain() { return access(false, () -> NativeValues.version(raw(obj("retain", obj())).get("version"))); }
    public Source openVersion(ReadVersion version) { check(); return new Source(this, Objects.requireNonNull(version)); }
    public void release(ReadVersion version) { access(false, () -> { raw(obj("release", NativeValues.wire(version))); return null; }); }
    public void allowQuery(ProcessRef peer, Table.Schema<?> table, long expectedRevision, boolean allow) {
        access(false, () -> {
            raw(obj("query_policy", obj("peer", peer(peer), "table", table.id(), "expected_revision", counter(expectedRevision, 0), "allow", allow)));
            return null;
        });
    }
    public Query.Job startQuery(Table.Schema<?> schema, Query.Plan plan) {
        table(schema);
        return access(false, () -> {
            JsonObject value = object(raw(obj("query_start", obj("id", schema.id(), "plan", plan.wire(limit("table_cell_bytes"))))).get("query"));
            return new Query.Job(number(value.get("result"), 1), NativeValues.wide(value.get("correlation"), true), NativeValues.version(value.get("source")));
        });
    }
    public void closeQuery(long result, Query.CloseReason reason) {
        access(false, () -> { raw(obj("query_close", obj("result", counter(result, 1), "reason", reason.name().toLowerCase(Locale.ROOT)))); return null; });
    }
    public Query.ResultReader result(BigInteger correlation) { check(); return new Query.ResultReader(this, positive(correlation)); }
}
