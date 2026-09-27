package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import io.transit.client.internal.*;
import io.transit.sdk.station.Types.*;
import static io.transit.client.internal.Values.*;
import java.nio.file.Path;
import java.nio.charset.StandardCharsets;
import java.util.*;

final class Bridge implements Worker.State<Void> {
    final Port port;
    final JsonObject caps;
    static Bridge local(Path nativeHost) { return new Bridge(obj("local_codec", true), nativeHost); }
    static Bridge open(ServiceConfig config, FailurePolicy failure) {
        Activation activation = config.activation(); ClientConfig client = config.client();
        Bridge bridge = new Bridge(obj("url", client.endpoint().toString(), "seed_file", activation.credential().seedFile().toString(), "timeout_ms", client.timeoutMillis(),
            "growing_server", obj("profile", "growing_v3", "realm", activation.process().realm(), "principal", activation.credential().principal(),
                "pid", activation.process().pid(), "generation", activation.generation(), "association", config.association(), "timeout_ms", client.timeoutMillis(),
                "failure_policy", failure == FailurePolicy.STOP ? "stop" : "block_input", "query_results", config.queryResults())), client.nativeHost());
        try {
            if (config.queryResults() && !bool(bridge.caps.get("query_results"))) throw new TransitException(TransitException.Kind.UNSUPPORTED_CAPABILITY, "query-results");
            var caps = Operations.capabilities(bridge.port, activation.credential());
            if (!caps.associationLookup() || !caps.scopedRetry() || !caps.retainedVersions()) throw new TransitException(TransitException.Kind.UNSUPPORTED_CAPABILITY, "authority-capabilities");
            return bridge;
        } catch (RuntimeException | Error error) { bridge.close(); throw error; }
    }
    private Bridge(JsonObject config, Path nativeHost) {
        if (!"0.2.0".equals(Client.class.getPackage().getImplementationVersion())) throw incompatible("client-sdk-version");
        JsonObject schemas = resource("/io/transit/sdk/client/schemas.json");
        resource("/io/transit/sdk/station/schemas.json").entrySet().forEach(entry -> schemas.add(entry.getKey(), entry.getValue()));
        port = new Port("station", nativeHost, config, schemas, "HostRequest");
        try {
            JsonObject hello = object(port.request(obj("hello", obj()), "hello"));
            if (!hello.keySet().equals(Set.of("host_version", "station_version", "transit_version"))) throw incompatible("station-version");
            for (String name : hello.keySet()) if (number(hello.get(name), 1) != 1) throw incompatible("station-version");
            caps = object(port.request(obj("growing_capabilities", obj()), "native-capabilities", false, "GrowingCapabilities"));
            if (number(caps.get("version"), 1) != 1 || !"growing_v3".equals(string(caps.get("profile")))) throw incompatible("station-profile");
            for (String name : List.of("gated_dispatch", "retained_confirmation", "scoped_turns", "paged_state", "tables", "retained_sources")) {
                if (!bool(caps.get(name))) throw new TransitException(TransitException.Kind.UNSUPPORTED_CAPABILITY, "native-capabilities");
            }
        } catch (RuntimeException | Error error) { port.close(); throw error; }
    }
    int limit(String name) { return Math.toIntExact(number(caps.get(name), 1)); }
    void httpCapability(String name) {
        if (!bool(caps.get(name))) throw new TransitException(TransitException.Kind.UNSUPPORTED_CAPABILITY, name);
    }
    JsonObject httpCodec(JsonObject action) {
        httpCapability("http_requests");
        return object(port.request(obj("http_codec", action), "http-codec", false, "HttpCodecResult"));
    }
    JsonObject httpRead(JsonObject action) {
        httpCapability("http_replay");
        return object(port.request(obj("growing_http_read", action), "http-replay", false, "HttpReadResult"));
    }    void grpcCapability(String name) {
        if (!bool(caps.get(name))) throw new TransitException(TransitException.Kind.UNSUPPORTED_CAPABILITY, name);
    }
    JsonObject grpcCodec(JsonObject action) {
        grpcCapability("grpc_requests");
        return object(port.request(obj("grpc_codec", action), "grpc-codec", false, "GrpcCodecResult"));
    }
    JsonObject grpcRead(JsonObject action) {
        grpcCapability("grpc_replay");
        return object(port.request(obj("growing_grpc_read", action), "grpc-replay", false, "GrpcReadResult"));
    }
    JsonObject prepare() { return object(port.request(obj("growing_prepare", System.currentTimeMillis() + 30_000), "prepare-turn", false, "GrowingEvent")); }
    JsonObject apply(long scope, JsonObject action) {
        return object(port.request(obj("growing_apply", obj("scope", scope, "action", action)), "apply", false, "GrowingResult"));
    }
    void finish(long scope, boolean failed) { port.request(obj("growing_finish_result", obj("scope", scope, "failed", failed)), "finish"); }
    void discard(long scope) { port.request(obj("growing_discard", scope), "discard"); }
    JsonObject dispatch() { return object(port.request(obj("growing_dispatch", obj()), "dispatch", true, "GrowingEvent")); }
    FrozenMutation pending(JsonObject event) {
        Purpose purpose = Purpose.valueOf(string(event.get("pending_kind")).toUpperCase(Locale.ROOT));
        byte[] bytes = string(port.request(obj("growing_pending", obj()), "pending")).getBytes(StandardCharsets.UTF_8);
        try (PendingMutation pending = Operations.recoverMutation(port, bytes)) {
            String command = pending.info().command();
            boolean matches = switch (purpose) {
                case PERMIT -> command.equals("begin_turn"); case OPEN -> command.equals("open_view");
                case COMMIT -> command.equals("turn") || command.equals("turn_with_versions");
            };
            if (!matches) throw incompatible("pending-purpose");
            return new FrozenMutation(pending.info().identity(), purpose, number(event.get("pending_input"), 1), new Bytes(bytes));
        }
    }
    JsonObject confirmation(FrozenMutation pending) {
        try {
            JsonObject event = object(port.request(obj("growing_confirmation", obj()), "observe-confirmation", false, "GrowingEvent"));
            JsonElement confirmation = event.get("confirmation");
            return confirmation != null && !confirmation.isJsonNull() && matches(object(confirmation), pending) ? event : null;
        } catch (TransitException error) { if (error.kind() == TransitException.Kind.TURN_EXPIRED) return null; throw error; }
    }
    static boolean matches(JsonObject value, FrozenMutation pending) {
        return string(value.get("kind")).equals(pending.purpose().name().toLowerCase(Locale.ROOT)) && number(value.get("input"), 1) == pending.inputPosition();
    }
    @Override public Void evidence() { return null; }
    @Override public void close() { port.close(); }
}
