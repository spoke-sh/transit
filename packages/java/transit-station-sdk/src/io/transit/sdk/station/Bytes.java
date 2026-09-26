package io.transit.sdk.station;
import java.util.Arrays;
import io.transit.client.internal.Values;
/** Owned immutable bytes. The original IPC interface returns a copy. */
public final class Bytes {
    private final byte[] value;
    public Bytes(byte[] value) { this.value = Values.bytes(value, Values.MAX_BODY); }
    public byte[] copy() { return value.clone(); }
    public int size() { return value.length; }
    @Override public boolean equals(Object other) { return other instanceof Bytes bytes && Arrays.equals(value, bytes.value); }
    @Override public int hashCode() { return Arrays.hashCode(value); }
    @Override public String toString() { return "Bytes[length=" + value.length + "]"; }
}
