package io.transit.client;

import com.google.gson.*;
import io.transit.client.internal.*;
import io.transit.client.Outcomes.*;
import static io.transit.client.internal.Values.*;
import java.util.*;
import java.util.concurrent.CompletableFuture;

/** Independent raw Transit client. Every operation admits at most one owned job. */
public final class Client implements AutoCloseable {
    public static final String VERSION = "0.0.1";
    private static final class State implements Worker.State<Shutdown> {
        final Port port;
        AdmissionReceipt lastAdmission;
        MutationReceipt lastMutation;
        State(ClientConfig config) {
            port = new Port("client", config.nativeHost(), obj("url", config.endpoint().toString(), "timeout_ms", config.timeoutMillis()),
                resource("/io/transit/sdk/client/schemas.json"), "ClientHostRequest");
            try { Operations.negotiateClient(port); }
            catch (RuntimeException | Error error) { port.close(); throw error; }
        }
        @Override public Shutdown evidence() { return new Shutdown(lastAdmission, lastMutation); }
        @Override public void close() { port.close(); }
    }
    private final Worker<State, Shutdown> worker;
    private Client(ClientConfig config) { Objects.requireNonNull(config); worker = new Worker<>(() -> new State(config)); }
    /** Startup is blocking and bounded; use an owned application task if needed. */
    public static Client open(ClientConfig config) { return new Client(config); }
    public CompletableFuture<Capabilities> capabilities(Credential credential) {
        Objects.requireNonNull(credential);
        return worker.submit(state -> Operations.capabilities(state.port, credential));
    }
    public CompletableFuture<PendingSend> prepareSend(ProcessRef peer, byte[] value, Credential credential, long sequence) {
        Objects.requireNonNull(peer); Objects.requireNonNull(credential); counter(sequence, 1);
        if (peer.realm() != credential.realm()) throw new IllegalArgumentException("Peer and credential must share a realm");
        return worker.submitPrepared(() -> {
            byte[] payload = bytes(value, CONTRACT.getAsJsonObject("limits").get("value_bytes").getAsInt());
            return state -> Operations.recoverSend(state.port, Operations.prepare(state.port, 6, credential,
                obj("realm", credential.realm(), "principal", credential.principal(), "sequence", sequence,
                    "command", obj("send", obj("pid", peer.pid(), "value", HexFormat.of().formatHex(payload))))));
        });
    }
    public CompletableFuture<PendingSend> recoverSend(byte[] value) {
        return worker.submitPrepared(() -> { byte[] frozen = bytes(value, MAX_BODY); return state -> Operations.recoverSend(state.port, frozen); });
    }
    public CompletableFuture<PendingMutation> recoverMutation(byte[] value) {
        return worker.submitPrepared(() -> { byte[] frozen = bytes(value, MAX_BODY); return state -> Operations.recoverMutation(state.port, frozen); });
    }
    public CompletableFuture<SendOutcome> dispatch(PendingSend pending) {
        Objects.requireNonNull(pending);
        return worker.submitPrepared(() -> {
            byte[] frozen = pending.export();
            return state -> {
                try (PendingSend checked = Operations.recoverSend(state.port, frozen)) {
                    if (!checked.info().equals(pending.info())) throw new IllegalArgumentException("Pending metadata mismatch");
                }
                state.lastAdmission = null;
                try {
                    JsonObject result = object(state.port.request(obj("call", text(frozen)), "dispatch", true, null));
                    state.lastAdmission = new AdmissionReceipt(number(result.get("position"), 1));
                    return new Admitted(state.lastAdmission);
                } catch (TransitException error) {
                    if (error.rejected()) return new Rejected(error);
                    if (error.kind() == TransitException.Kind.UNKNOWN_OUTCOME) return new Uncertain(frozen, error);
                    return new Uncertain(frozen, new TransitException(TransitException.Kind.UNKNOWN_OUTCOME, 6, null, "receipt"));
                } catch (RuntimeException error) { return new Uncertain(frozen, new TransitException(TransitException.Kind.UNKNOWN_OUTCOME, 6, null, "receipt")); }
            };
        });
    }
    public CompletableFuture<MutationOutcome> dispatchMutation(PendingMutation pending) {
        Objects.requireNonNull(pending);
        return worker.submitPrepared(() -> {
            byte[] frozen = pending.export();
            return state -> {
                try (PendingMutation checked = Operations.recoverMutation(state.port, frozen)) {
                    if (!checked.info().equals(pending.info())) throw new IllegalArgumentException("Pending metadata mismatch");
                }
                state.lastMutation = null;
                try {
                    JsonObject result = object(state.port.request(obj("call", text(frozen)), "dispatch", true, null));
                    state.lastMutation = new MutationReceipt(number(result.get("position"), 1));
                    return new Confirmed(state.lastMutation);
                } catch (TransitException error) {
                    if (error.rejected()) return new Rejected(error);
                    if (error.kind() == TransitException.Kind.UNKNOWN_OUTCOME) return new Uncertain(frozen, error);
                    return new Uncertain(frozen, new TransitException(TransitException.Kind.UNKNOWN_OUTCOME, 6, null, "receipt"));
                } catch (RuntimeException error) { return new Uncertain(frozen, new TransitException(TransitException.Kind.UNKNOWN_OUTCOME, 6, null, "receipt")); }
            };
        });
    }
    public CompletableFuture<Shutdown> evidence() { return worker.submit(State::evidence); }
    public CompletableFuture<Shutdown> closeAsync() { return worker.closeAsync(); }
    /** Available after close, including when the caller cancelled its close future. */
    public Shutdown retainedEvidence() { return worker.retainedEvidence(); }
    public Shutdown closeSnapshot() { return worker.closeSnapshot(); }
    @Override public void close() { worker.close(); }
}
