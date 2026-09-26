package io.transit.sdk.station;
import java.nio.charset.StandardCharsets;
import java.util.Objects;
/** Typed application KV key, independent of a turn. */
public final class Key<T> {
    private final Bytes name;
    private final Codec<T> codec;
    public Key(byte[] name, Codec<T> codec) {
        if (name.length == 0 || name[0] == 0) throw new IllegalArgumentException("Use a nonempty application key outside the reserved prefix");
        this.name = new Bytes(name); this.codec = Objects.requireNonNull(codec);
    }
    public Key(String name, Codec<T> codec) { this(io.transit.client.internal.Values.text(name, io.transit.client.internal.Values.MAX_BODY).getBytes(StandardCharsets.UTF_8), codec); }
    public Bytes name() { return name; }
    public Codec<T> codec() { return codec; }
    @Override public String toString() { return "Key[application codec]"; }
}
