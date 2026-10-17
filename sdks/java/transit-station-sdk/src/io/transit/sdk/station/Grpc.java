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

/** Owned RPC values over shared Zig preparation, publication and capture validation. */
public final class Grpc {
    private Grpc() {}
    public enum Shape { UNARY, SERVER_STREAMING, CLIENT_STREAMING, BIDI }
    public record Method(String path, Shape shape, Bytes descriptorDigest) {
        public Method { text(path,512); Objects.requireNonNull(shape); Objects.requireNonNull(descriptorDigest); if(descriptorDigest.size()!=32) throw new IllegalArgumentException("Expected descriptor SHA-256"); }
    }
    public sealed interface MetadataValue permits Literal, SecretRef {}
    public record Literal(Bytes bytes) implements MetadataValue {
        public Literal { Objects.requireNonNull(bytes); if(bytes.size()>8192) throw new IllegalArgumentException("Oversized metadata"); }
    }
    public record SecretRef(String binding, BigInteger version) implements MetadataValue {
        public SecretRef { text(binding,128); positive(version); }
    }
    public record Metadata(String name, MetadataValue value) {
        public Metadata { text(name,8192); Objects.requireNonNull(value); }
    }
    public record Request(Method method, List<Metadata> metadata) {
        public Request { Objects.requireNonNull(method); metadata=List.copyOf(metadata); if(metadata.size()>64) throw new IllegalArgumentException("Too many metadata fields"); }
    }
    public record Options(BigInteger endpointRevision, long reconcileBeforeMillis, long maxAttempts) {
        public Options { positive(endpointRevision); counter(reconcileBeforeMillis, 1); if (maxAttempts < 1 || maxAttempts > 0xffffffffL) throw new IllegalArgumentException("Invalid attempt count"); }
    }
    private static BigInteger positive(BigInteger value) { u64(value); if (value.signum() == 0) throw new IllegalArgumentException("Expected nonzero u64"); return value; }
    private static JsonArray wire(List<Metadata> fields) {
        JsonArray result=new JsonArray();
        for(Metadata field:fields) result.add(obj("name",field.name(),"value",switch(field.value()) {
            case Literal literal -> obj("literal",hex(literal.bytes()));
            case SecretRef secret -> obj("secret",obj("binding",secret.binding(),"version",secret.version().toString()));
        }));
        return result;
    }
    static String hex(Bytes value) { return HexFormat.of().formatHex(value.copy()); }
    public static final class Prepared {
        private final ResourceRef resource;
        private final BigInteger namespace;
        private final Bytes reference, metadata, batch;
        private Prepared(ResourceRef resource, BigInteger namespace, Bytes reference, Bytes metadata, Bytes batch) {
            this.resource = resource; this.namespace = namespace; this.reference = reference; this.metadata = metadata; this.batch = batch;
        }
        public ResourceRef resource() { return resource; }
        public BigInteger namespace() { return namespace; }
        public Bytes reference() { return reference; }
        public Bytes metadata() { return metadata; }
        public Bytes batch() { return batch; }
        String referenceHex() { return hex(reference); }
        String metadataHex() { return hex(metadata); }
        String batchHex() { return hex(batch); }
    }
    private static JsonObject local(JsonObject action, Path nativeHost, boolean release) {
        try (Worker<Bridge, Void> worker = new Worker<>(() -> Bridge.local(nativeHost))) {
            return Worker.await(worker.submit(bridge -> {
                if (release) bridge.grpcCapability("grpc_release");
                return bridge.grpcCodec(action);
            }));
        }
    }
    public static Method method(byte[] descriptor,String path) { return method(descriptor,path,null); }
    public static Method method(byte[] descriptor,String path,Path nativeHost) {
        text(path,512);
        JsonObject value=object(object(local(obj("descriptor",obj("bytes",HexFormat.of().formatHex(bytes(descriptor,65536)),"method",path)),nativeHost,false).get("descriptor")).get("method"));
        return new Method(string(value.get("path")),Shape.valueOf(string(value.get("shape")).toUpperCase(Locale.ROOT)),new Bytes(unhex(value.get("descriptor_digest"),32)));
    }
    public static Prepared prepare(ResourceRef resource,BigInteger namespace,Request request,List<Bytes> messages,Options options) { return prepare(resource,namespace,request,messages,options,null); }
    public static Prepared prepare(ResourceRef resource,BigInteger namespace,Request request,List<Bytes> messages,Options options,Path nativeHost) {
        Objects.requireNonNull(resource); positive(namespace); Objects.requireNonNull(request); Objects.requireNonNull(options);
        messages=List.copyOf(messages); if(messages.size()>64) throw new IllegalArgumentException("Too many messages");
        JsonArray batch=new JsonArray(); for(Bytes message:messages) { if(message.size()>16384) throw new IllegalArgumentException("Oversized message"); batch.add(hex(message)); }
        Method method=request.method();
        JsonObject prepared=object(local(obj("prepare",obj("resource",resource.resource(),"namespace",namespace.toString(),
            "request",obj("method",obj("path",method.path(),"shape",method.shape().name().toLowerCase(Locale.ROOT),"descriptor_digest",hex(method.descriptorDigest())),"metadata",wire(request.metadata())),"messages",batch,
            "endpoint_revision",options.endpointRevision().toString(),"reconcile_before_ms",options.reconcileBeforeMillis(),"max_attempts",options.maxAttempts())),nativeHost,false).get("prepared"));
        return new Prepared(resource,namespace,new Bytes(unhex(prepared.get("reference"),145)),new Bytes(unhex(prepared.get("metadata"),8192)),new Bytes(unhex(prepared.get("batch"),65544)));
    }
    public enum Phase { OBSERVED, CLOSED_UNKNOWN, NOT_DISPATCHED }
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
            status = value.get("status").isJsonNull() ? null : Math.toIntExact(number(value.get("status"), 0));
            reference = value.get("reference").isJsonNull() ? null : new Bytes(unhex(value.get("reference"), 256));
            if (status != null && status > 16) throw incompatible("grpc-status");
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
        boolean release = owned.length >= 4 && owned[0] == 'G' && owned[1] == 'R' && owned[2] == 'K' && owned[3] == '1';
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
        @Override public String typeId() { return "transit.grpc.reply+" + application.typeId(); }
        @Override public long version() { return 1; }
        @Override public int maxEncodedBytes() { return Math.max(232, application.maxEncodedBytes()); }
        @Override public byte[] encode(Message<T> value) {
            if (value instanceof Application<T> message) return application.encode(message.value());
            throw NativeValues.codecError();
        }
        @Override public Message<T> decode(byte[] value) {
            if (value.length >= 4 && value[0] == 'G' && value[1] == 'R' && (value[2] == 'R' || value[2] == 'F' || value[2] == 'K') && value[3] == '1')
                return new Received<>(decodeReply(realm, value, nativeHost));
            return new Application<>(application.decode(value));
        }
    }
    public enum ReplayPolicy { CAPTURED, REQUIRE_UNREDACTED }
    public enum PartKind { REQUEST_METADATA, REQUEST_BATCH, ENDPOINT_POLICY, INITIAL_METADATA, RESPONSE_MESSAGE, RESPONSE_BODY, HALF_CLOSE, TRAILERS, TIMING, OMISSION, COMPLETION }
    public record Part(PartKind kind, Bytes data, boolean complete) {
        public Part { Objects.requireNonNull(kind); Objects.requireNonNull(data); if (data.size() > 256) throw new IllegalArgumentException("Oversized RPC part"); }
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
            CompletableFuture<Optional<Part>> future = owner.grpcAccess(bridge -> {
                if (closed) throw new TransitException(TransitException.Kind.CLOSED, "grpc-reader");
                if (failed.get()) throw new TransitException(TransitException.Kind.READ_FAILED, -1, "GrpcReplayFailed", "grpc-reader");
                try {
                    JsonElement part = bridge.grpcRead(obj("next", identity)).get("part");
                    if (part.isJsonNull()) { if (!complete) throw incompatible("grpc-incomplete"); return Optional.empty(); }
                    JsonObject value = object(part);
                    Part out = new Part(PartKind.valueOf(string(value.get("kind")).toUpperCase(Locale.ROOT)), new Bytes(unhex(value.get("bytes"), 256)), bool(value.get("complete")));
                    Optional<Part> result = Optional.of(out); complete = out.complete(); return result;
                } catch (RuntimeException | Error error) { failed.set(true); throw error; }
            });
            future.whenComplete((value, error) -> { if (future.isCancelled()) failed.set(true); });
            return future;
        }
        public CompletableFuture<Void> closeAsync() {
            return owner.grpcAccess(bridge -> {
                if (!closed) { if (!bool(bridge.grpcRead(obj("close", identity)).get("closed"))) throw incompatible("grpc-close"); closed = true; }
                return null;
            });
        }
        @Override public void close() { owner.grpcBlockingClose(); Worker.await(closeAsync()); }
    }
}
