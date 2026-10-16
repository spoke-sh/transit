package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import io.transit.client.internal.Worker;
import static io.transit.client.internal.Values.*;
import java.math.BigInteger;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.atomic.AtomicBoolean;

/** Owned HTTP values over shared Zig preparation, publication and capture validation. */
public final class Http {
    private Http() {}
    public enum Method { GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS }
    public sealed interface Piece permits Literal, Variable, SecretRef {}
    public record Literal(String value) implements Piece {
        public Literal { text(value, 8192); }
    }
    public record Variable(String name, String value) implements Piece {
        public Variable { text(name, 128); text(value, 8192); }
    }
    public record SecretRef(String binding, BigInteger version) implements Piece {
        public SecretRef { text(binding, 128); positive(version); }
    }
    public record Header(String name, List<Piece> value) {
        public Header { text(name, 8192); value = pieces(value); }
    }
    public record Request(Method method, List<Piece> target, List<Header> headers) {
        public Request { Objects.requireNonNull(method); target = pieces(target); headers = List.copyOf(headers); if (headers.size() > 64) throw new IllegalArgumentException("Too many headers"); }
    }
    public record Options(BigInteger endpointRevision, long reconcileBeforeMillis, long maxAttempts) {
        public Options { positive(endpointRevision); counter(reconcileBeforeMillis, 1); if (maxAttempts < 1 || maxAttempts > 0xffffffffL) throw new IllegalArgumentException("Invalid attempt count"); }
    }
    private static BigInteger positive(BigInteger value) { u64(value); if (value.signum() == 0) throw new IllegalArgumentException("Expected nonzero u64"); return value; }
    private static List<Piece> pieces(List<Piece> value) { List<Piece> result = List.copyOf(value); if (result.size() > 128) throw new IllegalArgumentException("Too many pieces"); return result; }
    private static JsonArray wire(List<Piece> pieces) {
        JsonArray result = new JsonArray();
        for (Piece piece : pieces) result.add(switch (piece) {
            case Literal literal -> obj("literal", literal.value());
            case Variable variable -> obj("variable", obj("name", variable.name(), "value", variable.value()));
            case SecretRef secret -> obj("secret", obj("binding", secret.binding(), "version", secret.version().toString()));
        });
        return result;
    }
    static String hex(Bytes value) { return HexFormat.of().formatHex(value.copy()); }
    public static final class Prepared {
        private final ResourceRef resource;
        private final BigInteger namespace;
        private final Bytes reference, metadata, body;
        private Prepared(ResourceRef resource, BigInteger namespace, Bytes reference, Bytes metadata, Bytes body) {
            this.resource = resource; this.namespace = namespace; this.reference = reference; this.metadata = metadata; this.body = body;
        }
        public ResourceRef resource() { return resource; }
        public BigInteger namespace() { return namespace; }
        public Bytes reference() { return reference; }
        public Bytes metadata() { return metadata; }
        public Bytes body() { return body; }
        String referenceHex() { return hex(reference); }
        String metadataHex() { return hex(metadata); }
        String bodyHex() { return hex(body); }
    }
    private static JsonObject local(JsonObject action, Path nativeHost, boolean release) {
        try (Worker<Bridge, Void> worker = new Worker<>(() -> Bridge.local(nativeHost))) {
            return Worker.await(worker.submit(bridge -> {
                if (release) bridge.httpCapability("http_release");
                return bridge.httpCodec(action);
            }));
        }
    }
    public static Prepared prepare(ResourceRef resource, BigInteger namespace, Request request, byte[] body, Options options) {
        return prepare(resource, namespace, request, body, options, null);
    }
    public static Prepared prepare(ResourceRef resource, BigInteger namespace, Request request, byte[] body, Options options, Path nativeHost) {
        Objects.requireNonNull(resource); positive(namespace); Objects.requireNonNull(request); Objects.requireNonNull(options);
        Bytes owned = new Bytes(bytes(body, 65536)); JsonArray headers = new JsonArray();
        for (Header header : request.headers()) headers.add(obj("name", header.name(), "value", wire(header.value())));
        JsonObject prepared = object(local(obj("prepare", obj("resource", resource.resource(), "namespace", namespace.toString(),
            "request", obj("method", request.method().name(), "target", wire(request.target()), "headers", headers), "body", hex(owned),
            "endpoint_revision", options.endpointRevision().toString(), "reconcile_before_ms", options.reconcileBeforeMillis(), "max_attempts", options.maxAttempts())), nativeHost, false).get("prepared"));
        return new Prepared(resource, namespace, new Bytes(unhex(prepared.get("reference"), 112)), new Bytes(unhex(prepared.get("metadata"), 8192)), owned);
    }
    public enum Phase { OBSERVED, CLOSED_UNKNOWN, NOT_DISPATCHED }
    public enum FollowupReason { RETRY, REDIRECT, RECONCILE, CANCEL }
    public enum Rejection { DENIED, INVALID_REQUEST, BUSY }
    public sealed interface Reply permits Outcome, Rejected, Released {}
    public record Rejected(Rejection reason, JsonObject diagnostic) implements Reply {
        public Rejected { Objects.requireNonNull(reason); diagnostic = Objects.requireNonNull(diagnostic).deepCopy(); }
        @Override public JsonObject diagnostic() { return diagnostic.deepCopy(); }
    }
    public record Released(ResourceRef resource, BigInteger exchange) implements Reply {
        public Released { Objects.requireNonNull(resource); positive(exchange); }
    }
    public static final class Outcome implements Reply {
        private final Phase phase;
        private final ResourceRef resource;
        private final BigInteger exchange;
        private final long effect, attempt;
        private final Integer status;
        private final Bytes reference;
        private final JsonObject diagnostic;
        private Outcome(long realm, JsonObject value) {
            diagnostic = object(value.get("diagnostic")).deepCopy();
            phase = Phase.valueOf(string(value.get("phase")).toUpperCase(Locale.ROOT));
            resource = new ResourceRef(realm, number(value.get("resource"), 1)); exchange = NativeValues.wide(value.get("exchange"), true);
            effect = number(value.get("effect"), 0); attempt = number(value.get("attempt"), 0);
            status = value.get("status").isJsonNull() ? null : Math.toIntExact(number(value.get("status"), 200));
            reference = value.get("reference").isJsonNull() ? null : new Bytes(unhex(value.get("reference"), 256));
            if (status != null && status > 599) throw incompatible("http-status");
        }
        public JsonObject diagnostic() { return diagnostic.deepCopy(); }
        public Phase phase() { return phase; }
        public ResourceRef resource() { return resource; }
        public BigInteger exchange() { return exchange; }
        public long effect() { return effect; }
        public long attempt() { return attempt; }
        public OptionalInt status() { return status == null ? OptionalInt.empty() : OptionalInt.of(status); }
        public Optional<Bytes> reference() { return Optional.ofNullable(reference); }
    }
    public static Reply decodeReply(long realm, byte[] bytes) { return decodeReply(realm, bytes, null); }
    public static Reply decodeReply(long realm, byte[] value, Path nativeHost) {
        counter(realm, 1);
        byte[] owned = bytes(value, 232);
        boolean release = owned.length >= 4 && owned[0] == 'H' && owned[1] == 'T' && owned[2] == 'K' && owned[3] == '1';
        JsonObject decoded = local(obj("outcome", HexFormat.of().formatHex(owned)), nativeHost, release);
        if (decoded.has("released")) {
            JsonObject released = object(decoded.get("released"));
            return new Released(new ResourceRef(realm, number(released.get("resource"), 1)), NativeValues.wide(released.get("exchange"), true));
        }
        if (decoded.has("rejected")) {
            JsonObject rejected = object(decoded.get("rejected"));
            return new Rejected(Rejection.valueOf(string(rejected.get("reason")).toUpperCase(Locale.ROOT)), object(rejected.get("diagnostic")));
        }
        return new Outcome(realm, object(decoded.get("outcome")));
    }
    public sealed interface Message<T> permits Application, Received {}
    public record Application<T>(T value) implements Message<T> { public Application { Objects.requireNonNull(value); } }
    public record Received<T>(Reply value) implements Message<T> { public Received { Objects.requireNonNull(value); } }
    public static final class ReplyCodec<T> implements Codec<Message<T>> {
        private final Codec<T> application;
        private final long realm;
        private final Path nativeHost;
        public ReplyCodec(Codec<T> application, long realm) { this(application, realm, null); }
        public ReplyCodec(Codec<T> application, long realm, Path nativeHost) { this.application = Objects.requireNonNull(application); this.realm = counter(realm, 1); this.nativeHost = nativeHost; }
        @Override public String typeId() { return "transit.http.reply+" + application.typeId(); }
        @Override public long version() { return 1; }
        @Override public int maxEncodedBytes() { return Math.max(232, application.maxEncodedBytes()); }
        @Override public byte[] encode(Message<T> value) {
            if (value instanceof Application<T> message) return application.encode(message.value());
            throw NativeValues.codecError();
        }
        @Override public Message<T> decode(byte[] value) {
            if (value.length >= 4 && value[0] == 'H' && value[1] == 'T' && (value[2] == 'R' || value[2] == 'F' || value[2] == 'K') && value[3] == '1')
                return new Received<>(decodeReply(realm, value, nativeHost));
            return new Application<>(application.decode(value));
        }
    }
    public enum ReplayPolicy { CAPTURED, REQUIRE_UNREDACTED }
    public enum PartKind { REQUEST_TEMPLATE, REQUEST_HEAD, REQUEST_BODY, RESPONSE_HEAD, RESPONSE_BODY, RESPONSE_TRAILERS, TIMING, OMISSION, COMPLETION }
    public record Part(PartKind kind, Bytes data, boolean complete) {
        public Part { Objects.requireNonNull(kind); Objects.requireNonNull(data); if (data.size() > 256) throw new IllegalArgumentException("Oversized HTTP part"); }
    }
    /** One runner-owned cursor. Cancelling a read view invalidates this reader. */
    public static final class Reader implements AutoCloseable {
        private final Runner<?> owner;
        private final long identity;
        private final AtomicBoolean failed = new AtomicBoolean();
        private volatile boolean complete, closed;
        Reader(Runner<?> owner, long identity) { this.owner = owner; this.identity = identity; }
        public boolean complete() { return complete; }
        public CompletableFuture<Optional<Part>> read() {
            CompletableFuture<Optional<Part>> future = owner.httpAccess(bridge -> {
                if (closed) throw new TransitException(TransitException.Kind.CLOSED, "http-reader");
                if (failed.get()) throw new TransitException(TransitException.Kind.READ_FAILED, -1, "HttpReplayFailed", "http-reader");
                try {
                    JsonElement part = bridge.httpRead(obj("next", identity)).get("part");
                    if (part.isJsonNull()) { if (!complete) throw incompatible("http-incomplete"); return Optional.empty(); }
                    JsonObject value = object(part);
                    Part out = new Part(PartKind.valueOf(string(value.get("kind")).toUpperCase(Locale.ROOT)), new Bytes(unhex(value.get("bytes"), 256)), bool(value.get("complete")));
                    Optional<Part> result = Optional.of(out); complete = out.complete(); return result;
                } catch (RuntimeException | Error error) { failed.set(true); throw error; }
            });
            future.whenComplete((value, error) -> { if (future.isCancelled()) failed.set(true); });
            return future;
        }
        public CompletableFuture<Void> closeAsync() {
            return owner.httpAccess(bridge -> {
                if (!closed) { if (!bool(bridge.httpRead(obj("close", identity)).get("closed"))) throw incompatible("http-close"); closed = true; }
                return null;
            });
        }
        @Override public void close() { owner.httpBlockingClose(); Worker.await(closeAsync()); }
    }
}
