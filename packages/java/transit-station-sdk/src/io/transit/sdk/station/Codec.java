package io.transit.sdk.station;

/** Application-owned, versioned payload contract. Encode/decode must be bounded. */
public interface Codec<T> {
    String typeId();
    long version();
    int maxEncodedBytes();
    byte[] encode(T value);
    T decode(byte[] bytes);
}
