package io.transit.sdk.station;
import io.transit.client.internal.*;
import java.nio.file.Path;
import java.util.HexFormat;
import static io.transit.client.internal.Values.*;
/** Local application frame encoding through Zig; no authority or credentials. */
public final class Station {
    private Station() {}
    public static <T> byte[] encodeCast(T value, Codec<T> codec) { return encodeCast(value, codec, null); }
    public static <T> byte[] encodeCast(T value, Codec<T> codec, Path nativeHost) {
        try (Worker<Bridge, Void> worker = new Worker<>(() -> Bridge.local(nativeHost))) {
            return Worker.await(worker.submit(bridge -> {
                int bound = bridge.limit("message_bytes");
                byte[] payload = NativeValues.encode(codec, value, bound);
                return unhex(bridge.port.request(obj("frame", obj("kind", 1, "correlation", "0", "payload", HexFormat.of().formatHex(payload))), "encode-cast"), bound + 13);
            }));
        }
    }
}
