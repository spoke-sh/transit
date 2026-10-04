package io.transit.client.internal;

import com.google.gson.*;
import io.transit.client.TransitException;
import static io.transit.client.TransitException.Kind.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermissions;
import java.util.Set;
import java.util.concurrent.*;

/** Used only by an owned worker, including construction and disposal. */
public final class Port implements AutoCloseable {
    private static final int MAXIMUM = Values.CONTRACT.getAsJsonObject("limits").get("host_line_bytes").getAsInt();
    private final NativeArtifact artifact;
    private final Path directory;
    private final Path configuration;
    private final Process process;
    private final JsonObject schemas;
    private final String requestName;
    private final int maximumStatus;
    private final ScheduledThreadPoolExecutor timer;
    private boolean closed;
    public Port(String family, Path override, JsonObject config, JsonObject schemas, String requestName) {
        this.schemas = schemas; this.requestName = requestName;
        maximumStatus = Values.resource("/io/transit/sdk/" + family + "/contract.json").getAsJsonObject("statuses")
            .entrySet().stream().mapToInt(entry -> entry.getValue().getAsInt()).max().orElseThrow();
        byte[] document = config.toString().getBytes(StandardCharsets.UTF_8);
        if (document.length > Values.CONTRACT.getAsJsonObject("limits").get("host_config_bytes").getAsInt()) throw new IllegalArgumentException("Native configuration exceeds its bound");
        artifact = NativeArtifact.open(family, override);
        Path created = null;
        try {
            created = Files.createTempDirectory("transit-java-config-", PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rwx------")));
            directory = created; configuration = directory.resolve("host.json");
            Files.createFile(configuration, PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rw-------")));
            Files.write(configuration, document);
            process = new ProcessBuilder(artifact.executable().toString(), configuration.toString()).redirectError(ProcessBuilder.Redirect.DISCARD).start();
        } catch (IOException | RuntimeException error) {
            RuntimeException failure = error instanceof IOException io ? Values.localIo("native-start", io) : (RuntimeException) error;
            if (created != null) {
                try { Files.deleteIfExists(created.resolve("host.json")); Files.deleteIfExists(created); }
                catch (IOException cleanup) { failure.addSuppressed(cleanup); }
            }
            try { artifact.close(); } catch (RuntimeException cleanup) { failure.addSuppressed(cleanup); }
            throw failure;
        }
        timer = new ScheduledThreadPoolExecutor(1, runnable -> {
            Thread thread = new Thread(runnable, "transit-port-deadline"); thread.setDaemon(true); return thread;
        });
        timer.setRemoveOnCancelPolicy(true);
    }
    public JsonObject schema(String name) {
        JsonObject schema = schemas.getAsJsonObject(name);
        if (schema == null) throw Values.incompatible("schema-name");
        return schema;
    }
    public JsonElement request(JsonObject request, String phase) { return request(request, phase, false, null); }
    public JsonElement request(JsonObject request, String phase, boolean mutation, String responseSchema) {
        if (closed) throw new TransitException(CLOSED, phase);
        Schema.require(schema(requestName), request);
        byte[] bytes = (request.toString() + "\n").getBytes(StandardCharsets.UTF_8);
        if (bytes.length > MAXIMUM) throw new IllegalArgumentException("Native line exceeds its bound");
        // The deadline only terminates I/O. It never publishes a rejection or owns a user continuation.
        ScheduledFuture<?> deadline = timer.schedule(process::destroyForcibly, 65, TimeUnit.SECONDS);
        JsonObject envelope;
        int status;
        try {
            if (process.getInputStream().available() != 0) throw new IOException("Unexpected native output");
            process.getOutputStream().write(bytes); process.getOutputStream().flush();
            ByteArrayOutputStream incoming = new ByteArrayOutputStream(1024);
            for (;;) {
                int value = process.getInputStream().read();
                if (value == -1) throw new EOFException();
                if (value == '\n') break;
                if (incoming.size() >= MAXIMUM - 1) throw new IOException("Oversized native line");
                incoming.write(value);
            }
            envelope = Values.object(Values.parse(incoming.toByteArray()));
            if (!envelope.keySet().equals(Set.of("status", "value"))) throw new IOException("Malformed native envelope");
            long parsed = Values.number(envelope.get("status"), 0);
            if (parsed > maximumStatus) throw new IOException("Unknown native status");
            status = (int) parsed;
            if (status == 0 && responseSchema != null) Schema.require(schema(responseSchema), envelope.get("value"));
        } catch (IOException | RuntimeException error) {
            closed = true; process.destroyForcibly();
            throw new TransitException(mutation ? UNKNOWN_OUTCOME : READ_FAILED, mutation ? 6 : 8, null, phase);
        } finally { deadline.cancel(false); }
        if (status != 0) throw Values.nativeError(status, envelope.get("value"), phase);
        return envelope.get("value");
    }
    @Override public void close() {
        closed = true;
        boolean interrupted = false;
        try {
            try { process.getOutputStream().close(); } catch (IOException ignored) { }
            for (;;) {
                try {
                    if (!process.waitFor(2, TimeUnit.SECONDS)) { process.destroyForcibly(); process.waitFor(); }
                    break;
                } catch (InterruptedException error) { interrupted = true; process.destroyForcibly(); }
            }
        } finally {
            timer.shutdownNow();
            try {
                process.getInputStream().close(); Files.deleteIfExists(configuration); Files.deleteIfExists(directory);
            } catch (IOException error) { throw new TransitException(CLEANUP, "port-close"); }
            finally { try { artifact.close(); } finally { if (interrupted) Thread.currentThread().interrupt(); } }
        }
    }
}
