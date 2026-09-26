package io.transit.client.internal;

import com.google.gson.*;
import io.transit.client.*;
import io.transit.client.Outcomes.*;
import static io.transit.client.internal.Values.*;
import java.nio.charset.StandardCharsets;

public final class Operations {
    private Operations() {}
    public static byte[] prepare(Port port, int kind, Credential credential, JsonObject document) {
        return string(port.request(obj("prepare", obj("kind", kind, "seed_file", credential.seedFile().toString(), "document", document.toString())), "prepare")).getBytes(StandardCharsets.UTF_8);
    }
    public static JsonObject metadata(Port port, byte[] bytes, boolean sendOnly) {
        JsonObject meta = object(port.request(obj("metadata", text(bytes)), "metadata", false, "OperationMetadata"));
        if (number(meta.get("version"), 1) != 1) throw incompatible("metadata-version");
        if (!"growing_v3".equals(string(meta.get("profile"))) || !"growing_command".equals(string(meta.get("kind"))) || meta.get("command").isJsonNull() ||
            (sendOnly && !"send".equals(string(meta.get("command"))))) throw new TransitException(TransitException.Kind.UNSUPPORTED_CAPABILITY, "recovery-kind");
        return meta;
    }
    private static long sequence(JsonElement value) {
        String sequence = string(value);
        if (!sequence.matches("[1-9][0-9]{0,15}")) throw incompatible("native-sequence");
        return counter(Long.parseLong(sequence), 1);
    }
    public static PendingSend recoverSend(Port port, byte[] bytes) {
        JsonObject meta = metadata(port, bytes, true);
        return new PendingSend(new PendingSend.Info(new OperationIdentity(string(meta.get("identity"))),
            new ProcessRef(number(meta.get("realm"), 1), number(meta.get("destination"), 1)), number(meta.get("principal"), 0), sequence(meta.get("sequence"))), bytes);
    }
    public static PendingMutation recoverMutation(Port port, byte[] bytes) {
        JsonObject meta = metadata(port, bytes, false);
        return new PendingMutation(new PendingMutation.Info(new OperationIdentity(string(meta.get("identity"))), number(meta.get("realm"), 1),
            number(meta.get("principal"), 0), sequence(meta.get("sequence")), string(meta.get("command"))), bytes);
    }
    public static Capabilities capabilities(Port port, Credential credential) {
        byte[] frozen = prepare(port, 7, credential, obj("realm", credential.realm(), "principal", credential.principal(), "kind", obj("capabilities", obj())));
        JsonObject result = object(port.request(obj("call", text(frozen)), "authority-capabilities"));
        JsonObject caps = object(object(result.get("body")).get("capabilities"));
        if (number(result.get("version"), 1) != 3 || number(caps.get("version"), 1) != 3 || !"growing_v1".equals(string(caps.get("profile")))) throw new TransitException(TransitException.Kind.UNSUPPORTED_CAPABILITY, "authority-profile");
        return new Capabilities(number(result.get("realm"), 1), number(result.get("position"), 0), number(result.get("principal_sequence"), 0),
            Math.toIntExact(number(caps.get("page_entries"), 1)), Math.toIntExact(number(caps.get("mutation_budget"), 1)), Math.toIntExact(number(caps.get("output_budget"), 1)),
            bool(caps.get("retained_read_versions")), bool(caps.get("association_lookup")), bool(caps.get("scoped_retry")), bool(caps.get("station")));
    }
    public static void negotiateClient(Port port) {
        JsonObject hello = object(port.request(obj("hello", obj()), "hello"));
        if (!hello.keySet().equals(java.util.Set.of("host_version", "transit_version")) ||
            number(hello.get("host_version"), 1) != 1 || number(hello.get("transit_version"), 1) != 1) throw incompatible("client-version");
        JsonObject caps = object(port.request(obj("capabilities", obj()), "native-capabilities", false, "ClientCapabilities"));
        if (number(caps.get("version"), 1) != 1 || !bool(caps.get("operation_metadata")) || !bool(caps.get("opaque_retry")) || !bool(caps.get("growing_v3"))) throw new TransitException(TransitException.Kind.UNSUPPORTED_CAPABILITY, "native-capabilities");
        JsonObject limits = CONTRACT.getAsJsonObject("limits");
        for (String name : new String[]{"value_bytes", "max_counter"}) if (number(caps.get(name), 1) != number(limits.get(name), 1)) throw incompatible("native-bounds");
        if (number(caps.get("max_line_bytes"), 1) != number(limits.get("host_line_bytes"), 1)) throw incompatible("native-line-bound");
    }
}
