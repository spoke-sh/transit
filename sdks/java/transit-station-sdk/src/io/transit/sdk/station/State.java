package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.TransitException;
import io.transit.sdk.station.Types.*;
import static io.transit.client.internal.Values.*;
import java.util.*;

public final class State {
    private final Turn turn;
    private final ReadVersion version;
    State(Turn turn, ReadVersion version) { this.turn = turn; this.version = version; }
    private String key(Key<?> key) { return HexFormat.of().formatHex(bytes(key.name().copy(), turn.limit("key_bytes"))); }
    public <T> Optional<T> find(Key<T> key) {
        return turn.access(true, () -> {
            String name = key(key);
            JsonObject request = version == null ? obj("get", name) : obj("version_get", obj("id", NativeValues.wire(version), "key", name));
            JsonElement value = turn.raw(request).get("value");
            return value.isJsonNull() ? Optional.empty() : Optional.of(NativeValues.decode(key.codec(), unhex(value, turn.limit("value_bytes")), turn.limit("value_bytes")));
        });
    }
    public <T> T require(Key<T> key) { return find(key).orElseThrow(() -> new TransitException(TransitException.Kind.MISSING_VALUE, "state-require")); }
    public <T> void put(Key<T> key, T value) {
        turn.access(false, () -> {
            writable(); String name = key(key);
            byte[] bytes = NativeValues.encode(key.codec(), value, turn.limit("value_bytes"));
            turn.raw(obj("put", obj("key", name, "value", HexFormat.of().formatHex(bytes)))); return null;
        });
    }
    public void delete(Key<?> key) { turn.access(false, () -> { writable(); turn.raw(obj("delete", key(key))); return null; }); }
    private void writable() { if (version != null) throw NativeValues.handlerError("retained-source-read-only"); }
    public Page<KVEntry> page() { return page(null); }
    public Page<KVEntry> page(Cursor cursor) {
        return turn.access(true, () -> {
            String opaque = cursor == null ? null : cursor.opaque();
            JsonObject request = version == null ? obj("page", opaque) : obj("version_page", obj("id", NativeValues.wire(version), "cursor", opaque));
            JsonObject page = object(turn.raw(request).get("page"));
            List<KVEntry> entries = new ArrayList<>();
            for (JsonElement item : page.getAsJsonArray("entries")) {
                if (item.isJsonNull()) continue;
                JsonObject value = object(item);
                entries.add(new KVEntry(new Bytes(unhex(value.get("key"), turn.limit("key_bytes"))),
                    new Bytes(unhex(value.get("value"), turn.limit("value_bytes"))), number(value.get("revision"), 0)));
            }
            return new Page<>(entries, NativeValues.cursor(page.get("next")), null);
        });
    }
}
