package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import io.transit.client.internal.Values;
import io.transit.sdk.station.Types.*;
import static io.transit.client.internal.Values.*;
import java.math.BigInteger;
import java.util.Objects;

final class NativeValues {
    private NativeValues() {}
    static TransitException codecError() { return new TransitException(TransitException.Kind.CODEC, "application-codec"); }
    static TransitException handlerError(String phase) { return new TransitException(TransitException.Kind.HANDLER, phase); }
    static TransitException normalize(Throwable error, String phase) {
        return error instanceof TransitException exception ? exception : handlerError(phase);
    }
    static int bound(Codec<?> codec, int bound) {
        try {
            if (text(codec.typeId(), 256).isEmpty() || codec.version() < 1 || codec.version() > 0xffffffffL || codec.maxEncodedBytes() < 1 || codec.maxEncodedBytes() > bound) throw codecError();
            return codec.maxEncodedBytes();
        } catch (RuntimeException error) { throw codecError(); }
    }
    static <T> byte[] encode(Codec<T> codec, T value, int bound) {
        try { int maximum = bound(codec, bound); return bytes(codec.encode(value), maximum); }
        catch (RuntimeException error) { throw codecError(); }
    }
    static <T> T decode(Codec<T> codec, byte[] bytes, int bound) {
        try { return Objects.requireNonNull(codec.decode(Values.bytes(bytes, bound(codec, bound)))); }
        catch (RuntimeException error) { throw codecError(); }
    }
    static BigInteger wide(JsonElement value, boolean nonzero) {
        String text = string(value);
        if (!text.matches("0|[1-9][0-9]{0,19}")) throw incompatible("native-u64");
        try { BigInteger result = u64(new BigInteger(text)); if (nonzero && result.signum() == 0) throw incompatible("native-u64"); return result; }
        catch (IllegalArgumentException error) { throw incompatible("native-u64"); }
    }
    static long signed(JsonElement value) {
        String text = string(value);
        if (!text.matches("0|-?[1-9][0-9]{0,18}")) throw incompatible("native-i64");
        try { return Long.parseLong(text); } catch (NumberFormatException error) { throw incompatible("native-i64"); }
    }
    static Bytes digest(JsonElement value) {
        if (!value.isJsonArray() || value.getAsJsonArray().size() != 32) throw incompatible("native-digest");
        byte[] bytes = new byte[32]; int index = 0;
        for (JsonElement byteValue : value.getAsJsonArray()) {
            long n = number(byteValue, 0); if (n > 255) throw incompatible("native-digest"); bytes[index++] = (byte) n;
        }
        return new Bytes(bytes);
    }
    static Basis basis(JsonElement value, long realm) {
        JsonObject object = object(value);
        return new Basis(new ResourceRef(realm, number(object.get("resource"), 1)), number(object.get("revision"), 0), digest(object.get("schema")));
    }
    static ReadVersion version(JsonElement value) {
        JsonObject object = object(value);
        return new ReadVersion(number(object.get("pid"), 1), number(object.get("input"), 1), Math.toIntExact(number(object.get("index"), 0)));
    }
    static JsonObject wire(ReadVersion version) { return obj("pid", version.pid(), "input", version.input(), "index", version.index()); }
    static Cursor cursor(JsonElement value) { return value.isJsonNull() ? null : new Cursor(string(value)); }
    static Origin origin(JsonElement value, long realm) {
        JsonObject object = object(value);
        if (object.has("external")) {
            JsonObject source = object(object.get("external"));
            return new ExternalOrigin(number(source.get("principal"), 0), number(source.get("policy_revision"), 0));
        }
        if (object.has("process")) {
            JsonObject source = object(object.get("process"));
            return new ProcessOrigin(new ProcessRef(realm, number(source.get("pid"), 1)), number(source.get("turn"), 1), number(source.get("output"), 0));
        }
        if (object.has("effect")) {
            JsonObject source = object(object.get("effect"));
            return new EffectOrigin(number(source.get("id"), 1), number(source.get("attempt"), 1), number(source.get("executor"), 0));
        }
        throw incompatible("native-origin");
    }
}
