package io.transit.station;

import com.google.gson.*;
import com.google.gson.stream.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.Set;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

/** Owned native port; framework and signing remain in Zig. */
public final class NativeHost implements AutoCloseable {
    private static final int MAXIMUM = 256 * 1024 * 2 + 16384;
    private static final ScheduledThreadPoolExecutor TIMERS = new ScheduledThreadPoolExecutor(1, runnable -> {
        Thread thread = new Thread(runnable, "transit-deadlines");
        thread.setDaemon(true);
        return thread;
    });
    static { TIMERS.setRemoveOnCancelPolicy(true); }
    public static final class TransitException extends RuntimeException {
        private static final long serialVersionUID = 1L;
        public final int status;
        public final transient JsonElement detail;
        public TransitException(int status, JsonElement detail) {
            super("Transit status " + status);
            this.status = status;
            this.detail = detail;
        }
    }
    private final Process process;
    private final ExecutorService worker = Executors.newSingleThreadExecutor(runnable -> new Thread(runnable, "transit-native-port"));
    private final AtomicBoolean busy = new AtomicBoolean();
    private final AtomicBoolean closed = new AtomicBoolean();
    private NativeHost(String executable, String config) throws IOException {
        process = new ProcessBuilder(executable, config).redirectError(ProcessBuilder.Redirect.INHERIT).start();
    }
    public static NativeHost open(String executable, String config) throws Exception {
        NativeHost host = new NativeHost(executable, config);
        try {
            JsonObject hello = host.request(tag("hello", new JsonObject())).get().getAsJsonObject();
            if (!hello.keySet().equals(Set.of("host_version", "station_version", "transit_version")) ||
                hello.get("host_version").getAsInt() != Contract.VERSION || hello.get("station_version").getAsInt() != Contract.VERSION ||
                hello.get("transit_version").getAsInt() != Contract.VERSION) throw failure(10, "Version mismatch");
            return host;
        } catch (Exception error) { host.close(); throw error; }
    }
    private static TransitException failure(int status, String detail) { return new TransitException(status, new JsonPrimitive(detail)); }
    public static JsonObject tag(String name, JsonElement value) {
        JsonObject object = new JsonObject(); object.add(name, value); return object;
    }
    private static JsonElement parse(byte[] bytes) throws IOException {
        var decoder = StandardCharsets.UTF_8.newDecoder();
        String text = decoder.decode(java.nio.ByteBuffer.wrap(bytes)).toString();
        JsonReader reader = new JsonReader(new StringReader(text));
        reader.setStrictness(Strictness.STRICT);
        reader.setNestingLimit(64);
        JsonElement result = JsonParser.parseReader(reader);
        if (reader.peek() != JsonToken.END_DOCUMENT) throw new IOException("Trailing JSON");
        return result;
    }
    private JsonElement exchange(JsonObject request) throws IOException {
        byte[] bytes = (request.toString() + "\n").getBytes(StandardCharsets.UTF_8);
        if (bytes.length > MAXIMUM) throw failure(1, "Oversized request");
        process.getOutputStream().write(bytes);
        process.getOutputStream().flush();
        ByteArrayOutputStream response = new ByteArrayOutputStream(1024);
        for (;;) {
            int value = process.getInputStream().read();
            if (value < 0) throw new EOFException("Native host exited");
            if (value == '\n') break;
            if (response.size() >= MAXIMUM) throw new IOException("Oversized response");
            response.write(value);
        }
        JsonElement parsed = parse(response.toByteArray());
        if (!parsed.isJsonObject()) throw new IOException("Malformed envelope");
        JsonObject envelope = parsed.getAsJsonObject();
        if (!envelope.keySet().equals(Set.of("status", "value")) || !envelope.get("status").isJsonPrimitive() ||
            !envelope.get("status").getAsJsonPrimitive().isNumber()) throw new IOException("Malformed status");
        int status = envelope.get("status").getAsBigDecimal().intValueExact();
        if (status < 0 || status > Contract.MAX_STATUS) throw new IOException("Unknown native status");
        if (status != 0) throw new TransitException(status, envelope.get("value"));
        return envelope.get("value");
    }
    public CompletableFuture<JsonElement> request(JsonObject request) {
        if (closed.get()) return CompletableFuture.failedFuture(failure(7, "Closed port"));
        if (!busy.compareAndSet(false, true)) return CompletableFuture.failedFuture(failure(9, "One operation per native host"));
        // Freeze caller-owned JSON before scheduling; callers may mutate theirs.
        JsonObject frozen = request.deepCopy();
        boolean uncertain = frozen.has("next") || frozen.has("call");
        CompletableFuture<JsonElement> result = new CompletableFuture<>();
        ScheduledFuture<?> timer = TIMERS.schedule(() -> {
            closed.set(true); process.destroyForcibly();
            result.completeExceptionally(failure(uncertain ? 6 : 7, "Native deadline elapsed"));
        }, 65, TimeUnit.SECONDS);
        result.whenComplete((value, error) -> {
            if (result.isCancelled()) { closed.set(true); process.destroyForcibly(); }
        });
        try {
            worker.execute(() -> {
                JsonElement value = null;
                Throwable failure = null;
                try { value = exchange(frozen); }
                catch (TransitException error) { failure = error; }
                catch (Exception error) {
                    closed.set(true); process.destroyForcibly();
                    failure = failure(uncertain ? 6 : 8, "Native completion unavailable or malformed");
                } finally { timer.cancel(false); busy.set(false); }
                if (failure == null) result.complete(value); else result.completeExceptionally(failure);
            });
        } catch (RejectedExecutionException error) {
            timer.cancel(false); busy.set(false); result.completeExceptionally(failure(7, "Closed worker"));
        }
        return result;
    }
    public CompletableFuture<JsonElement> next() { return request(tag("next", new JsonPrimitive(System.currentTimeMillis() + 30000))); }
    public CompletableFuture<JsonElement> apply(JsonObject action) { return request(tag("apply", action)); }
    public CompletableFuture<JsonElement> finish(boolean failed) { return request(tag("finish", new JsonPrimitive(failed))); }
    public CompletableFuture<JsonElement> pending() { return request(tag("pending", new JsonObject())); }
    public CompletableFuture<JsonElement> call(String frozen) { return request(tag("call", new JsonPrimitive(frozen))); }
    public CompletableFuture<JsonElement> prepare(int kind, String seedFile, JsonObject document) {
        JsonObject value = new JsonObject(); value.addProperty("kind", kind); value.addProperty("seed_file", seedFile); value.addProperty("document", document.toString());
        return request(tag("prepare", value));
    }
    public CompletableFuture<JsonElement> arrowCell(byte[] ipc, int row, int column) {
        JsonObject value = new JsonObject(); value.addProperty("ipc", java.util.HexFormat.of().formatHex(ipc)); value.addProperty("row", row); value.addProperty("column", column);
        return request(tag("arrow_cell", value));
    }
    @Override public void close() {
        closed.set(true);
        // Closing never acknowledges a message. A running submission may remain
        // uncertain; termination unblocks its reader before the executor stops.
        process.destroy();
        try { if (!process.waitFor(2, TimeUnit.SECONDS)) process.destroyForcibly(); }
        catch (InterruptedException error) { process.destroyForcibly(); Thread.currentThread().interrupt(); }
        worker.shutdown();
    }
}
