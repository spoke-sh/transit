package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import io.transit.client.Outcomes.MutationReceipt;
import io.transit.client.internal.Worker;
import io.transit.sdk.station.Types.*;
import static io.transit.client.internal.Values.*;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.function.Function;

/** Sequential handlers over one shared Zig server; local tasks are not durable state. */
public final class Runner<T> implements AutoCloseable {
    private static final class State<T> implements Worker.State<Shutdown> {
        final Bridge bridge;
        final Handler<T> handler;
        final Codec<T> codec;
        final FailurePolicy failure;
        final Recovery.Store store;
        final StopToken stop;
        final ProcessRef process;
        FrozenMutation pending;
        JsonObject confirmed;
        NeedsRecovery paused;
        Event lastEvent;
        boolean attempted;
        State(ServiceConfig config, Handler<T> handler, Codec<T> codec, FailurePolicy failure, Recovery recovery, StopToken stop) {
            this.handler = handler; this.codec = codec; this.failure = failure; this.stop = stop;
            this.store = recovery instanceof Recovery.PersistBeforeDispatch persist ? persist.store() : null;
            this.process = config.activation().process(); bridge = Bridge.open(config, failure);
            try { NativeValues.bound(codec, bridge.limit("message_bytes")); }
            catch (RuntimeException | Error error) { bridge.close(); throw error; }
        }
        Event record(Event event) { lastEvent = event; return event; }
        Event pause(Throwable error, String phase, MutationReceipt receipt) {
            paused = new NeedsRecovery(pending, phase, NativeValues.normalize(error, "recovery-" + phase), receipt);
            return record(paused);
        }
        Event accept(JsonObject event) {
            confirmed = event;
            MutationReceipt receipt;
            try {
                JsonObject value = object(event.get("confirmation"));
                if (!Bridge.matches(value, pending)) throw incompatible("confirmation-identity");
                receipt = new MutationReceipt(number(object(value.get("receipt")).get("position"), 1));
            } catch (RuntimeException error) { return pause(error, "confirm", null); }
            if (store != null) {
                try { store.confirmed(pending.identity(), receipt); }
                catch (Throwable error) { return pause(error, "confirm", receipt); }
            }
            Event result = string(event.get("event")).equals("blocked") ? new Blocked(pending.inputPosition(), receipt) :
                pending.purpose() == Purpose.COMMIT ? new Committed(pending.inputPosition(), receipt) : new Progress();
            pending = null; confirmed = null; paused = null; attempted = false;
            return record(result);
        }
        Event attempt() {
            if (pending == null) throw new TransitException(TransitException.Kind.CLOSED, "no-pending-mutation");
            if (confirmed != null) return accept(confirmed);
            if (attempted) {
                try { JsonObject event = bridge.confirmation(pending); if (event != null) return accept(event); }
                catch (TransitException error) { return pause(error, "observe_confirmation", null); }
            }
            if (stop.stopped()) return record(new Stopped());
            if (store != null) {
                try { store.beforeDispatch(pending); }
                catch (Throwable error) { return pause(error, "persist", null); }
            }
            if (stop.stopped()) return record(new Stopped());
            attempted = true;
            try { return accept(bridge.dispatch()); }
            catch (TransitException error) { return pause(error, "dispatch", null); }
        }
        boolean handle(JsonObject event) {
            Turn turn = new Turn(bridge, event, process, stop);
            TransitException error = null;
            try {
                JsonObject input = object(event.get("input"));
                String kind = string(input.get("kind"));
                long position = number(input.get("position"), 1);
                Origin origin = NativeValues.origin(input.get("origin"), process.realm());
                Incoming<T> message = null; Control control = null; ResultComplete result = null;
                switch (kind) {
                    case "cast", "call", "reply" -> {
                        T value = NativeValues.decode(codec, unhex(input.get("payload"), bridge.limit("message_bytes")), bridge.limit("message_bytes"));
                        message = switch (kind) {
                            case "cast" -> new Cast<>(value, position, origin);
                            case "call" -> new Call<>(value, position, origin, NativeValues.wide(input.get("correlation"), true));
                            default -> new Reply<>(value, position, origin, NativeValues.wide(input.get("correlation"), true));
                        };
                    }
                    case "cancel", "timeout" -> control = new Control(kind.equals("cancel") ? ControlKind.CANCEL : ControlKind.TIMEOUT,
                        position, origin, NativeValues.wide(input.get("correlation"), true));
                    case "result_complete" -> result = new ResultComplete(position, origin, NativeValues.wide(input.get("correlation"), true));
                    default -> throw NativeValues.handlerError("unsupported-input");
                }
                // Validate ingress before initialization can modify private state.
                if (bool(event.get("initializing")) && !stop.stopped()) handler.initialize(turn);
                if (!stop.stopped()) {
                    if (control != null) handler.onControl(turn, control);
                    else if (result != null) handler.onResult(turn, result);
                    else handler.onMessage(turn, Objects.requireNonNull(message));
                }
            } catch (Throwable failure) { error = NativeValues.normalize(failure, "handler"); }
            finally { turn.endScope(); }
            if (stop.stopped()) { bridge.discard(turn.scope); return false; }
            if (turn.poison != null) {
                // A dead port can make local discard unavailable; preserve the
                // failed read rather than replacing it with a cleanup error.
                try { bridge.discard(turn.scope); } catch (TransitException ignored) { }
                throw turn.poison;
            }
            try { bridge.finish(turn.scope, error != null); }
            catch (TransitException failure) {
                if (error != null && this.failure == FailurePolicy.STOP && "ForeignHandlerFailure".equals(failure.code())) throw error;
                throw failure;
            }
            return true;
        }
        Event next() {
            if (paused != null) return paused;
            if (stop.stopped()) return record(new Stopped());
            if (pending != null) return attempt();
            for (int count = 0; count < 16; count++) {
                if (stop.stopped()) return record(new Stopped());
                JsonObject event = bridge.prepare();
                switch (string(event.get("event"))) {
                    case "pending" -> { pending = bridge.pending(event); return attempt(); }
                    case "idle" -> { return record(new Idle()); }
                    case "blocked" -> { return record(new Blocked(null, null)); }
                    case "ready" -> { if (!handle(event)) return record(new Stopped()); }
                    case "progress" -> { }
                    default -> throw incompatible("native-event");
                }
            }
            return record(new Progress());
        }
        @Override public Shutdown evidence() { return new Shutdown(pending, lastEvent); }
        @Override public void close() { bridge.close(); }
    }
    private final long realm;
    private final StopToken stop = new StopToken();
    private final Worker<State<T>, Shutdown> worker;
    private Runner(ServiceConfig config, Handler<T> handler, Codec<T> codec, FailurePolicy failure, Recovery recovery) {
        Objects.requireNonNull(config); Objects.requireNonNull(handler); Objects.requireNonNull(codec); Objects.requireNonNull(failure); Objects.requireNonNull(recovery);
        realm = config.activation().process().realm();
        worker = new Worker<>(() -> new State<>(config, handler, codec, failure, recovery, stop));
    }
    public static <T> Runner<T> open(ServiceConfig config, Handler<T> handler, Codec<T> codec, FailurePolicy failure, Recovery recovery) {
        return new Runner<>(config, handler, codec, failure, recovery);
    }
    public CompletableFuture<Event> next() { return worker.submit(State::next); }
    public CompletableFuture<Event> reconcile() { return worker.submit(State::attempt); }
    public CompletableFuture<Shutdown> evidence() { return worker.submit(State::evidence); }
    <R> CompletableFuture<R> httpAccess(Function<Bridge, R> action) {
        return worker.submit(state -> {
            if (state.pending != null) throw new TransitException(TransitException.Kind.BUSY, "pending-mutation");
            return action.apply(state.bridge);
        });
    }
    void httpBlockingClose() { worker.checkBlockingClose(); }
    public CompletableFuture<Http.Reader> openHttp(Http.Outcome outcome) { return openHttp(outcome, Http.ReplayPolicy.CAPTURED); }
    public CompletableFuture<Http.Reader> openHttp(Http.Outcome outcome, Http.ReplayPolicy policy) {
        Objects.requireNonNull(outcome); Objects.requireNonNull(policy);
        return worker.submit(state -> {
            if (state.pending != null) throw new TransitException(TransitException.Kind.BUSY, "pending-mutation");
            if (outcome.phase() != Http.Phase.OBSERVED || outcome.reference().isEmpty() || outcome.resource().realm() != state.process.realm())
                throw new IllegalArgumentException("Expected an observed outcome in this realm");
            JsonObject value = state.bridge.httpRead(obj("open", obj("reference", Http.hex(outcome.reference().orElseThrow()), "policy", policy.name().toLowerCase(Locale.ROOT))));
            return new Http.Reader(this, number(value.get("opened"), 1));
        });
    }
    <R> CompletableFuture<R> grpcAccess(Function<Bridge, R> action) {
        return worker.submit(state -> {
            if (state.pending != null) throw new TransitException(TransitException.Kind.BUSY, "pending-mutation");
            return action.apply(state.bridge);
        });
    }
    void grpcBlockingClose() { worker.checkBlockingClose(); }
    public CompletableFuture<Grpc.Reader> openGrpc(Grpc.Outcome outcome) { return openGrpc(outcome, Grpc.ReplayPolicy.CAPTURED); }
    public CompletableFuture<Grpc.Reader> openGrpc(Grpc.Outcome outcome, Grpc.ReplayPolicy policy) {
        Objects.requireNonNull(outcome); Objects.requireNonNull(policy);
        return worker.submit(state -> {
            if (state.pending != null) throw new TransitException(TransitException.Kind.BUSY, "pending-mutation");
            if (outcome.phase() != Grpc.Phase.OBSERVED || outcome.reference().isEmpty() || outcome.resource().realm() != state.process.realm())
                throw new IllegalArgumentException("Expected an observed outcome in this realm");
            JsonObject value = state.bridge.grpcRead(obj("open", obj("reference", Grpc.hex(outcome.reference().orElseThrow()), "policy", policy.name().toLowerCase(Locale.ROOT))));
            return new Grpc.Reader(this, number(value.get("opened"), 1));
        });
    }
    public Document.Reader documents() { return new Document.Reader(this, realm); }
    <R> CompletableFuture<R> documentAccess(Function<Bridge, R> action) {
        return worker.submit(state -> {
            if (state.pending != null) throw new TransitException(TransitException.Kind.BUSY, "pending-mutation");
            return action.apply(state.bridge);
        });
    }
    public StopToken stopToken() { return stop; }
    public void stop() { stop.stop(); }
    public CompletableFuture<Shutdown> closeAsync() { worker.checkClose(); stop(); return worker.closeAsync(); }
    public Shutdown closeSnapshot() { worker.checkBlockingClose(); stop(); return worker.closeSnapshot(); }
    public Shutdown retainedEvidence() { return worker.retainedEvidence(); }
    @Override public void close() { closeSnapshot(); }
}
