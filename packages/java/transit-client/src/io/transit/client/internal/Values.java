package io.transit.client.internal;

import com.google.gson.*;
import com.google.gson.stream.*;
import io.transit.client.TransitException;
import static io.transit.client.TransitException.Kind.*;
import java.io.*;
import java.nio.*;
import java.nio.charset.*;
import java.math.BigInteger;
import java.util.*;

/** Exact-version SDK implementation interface, not an application wire API. */
public final class Values {
    private Values() {}
    public static final JsonObject CONTRACT = resource("/io/transit/sdk/client/contract.json");
    public static final int MAX_BODY = CONTRACT.getAsJsonObject("limits").get("max_body").getAsInt();
    public static final long MAX_COUNTER = CONTRACT.getAsJsonObject("limits").get("max_counter").getAsLong();
    public static final BigInteger U64_MAX = BigInteger.ONE.shiftLeft(64).subtract(BigInteger.ONE);
    public static long counter(long n, long minimum) {
        if (n < minimum || n > MAX_COUNTER) throw new IllegalArgumentException("Counter exceeds its bound");
        return n;
    }
    public static BigInteger u64(BigInteger n) {
        if (n == null || n.signum() < 0 || n.compareTo(U64_MAX) > 0) throw new IllegalArgumentException("Expected u64");
        return n;
    }
    public static String text(String value, int bound) {
        Objects.requireNonNull(value);
        try {
            if (StandardCharsets.UTF_8.newEncoder().encode(CharBuffer.wrap(value)).remaining() > bound) throw new IllegalArgumentException("Text exceeds its bound");
        } catch (CharacterCodingException error) { throw new IllegalArgumentException("Invalid UTF-8 text"); }
        return value;
    }
    public static String text(byte[] value) {
        try { return StandardCharsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(value)).toString(); }
        catch (CharacterCodingException error) { throw new IllegalArgumentException("Invalid UTF-8 bytes"); }
    }
    public static byte[] bytes(byte[] value, int bound) {
        Objects.requireNonNull(value);
        if (value.length > bound) throw new IllegalArgumentException("Bytes exceed their bound");
        return value.clone();
    }
    public static byte[] unhex(JsonElement value, int bound) {
        String hex = string(value);
        if (hex.length() > bound * 2 || !hex.matches("(?:[0-9a-f]{2})*")) throw incompatible("native-bytes");
        return HexFormat.of().parseHex(hex);
    }
    public static JsonObject object(JsonElement value) {
        if (value == null || !value.isJsonObject()) throw incompatible("native-object");
        return value.getAsJsonObject();
    }
    public static String string(JsonElement value) {
        if (value == null || !value.isJsonPrimitive() || !value.getAsJsonPrimitive().isString()) throw incompatible("native-string");
        return value.getAsString();
    }
    public static long number(JsonElement value, long minimum) {
        try {
            if (value == null || !value.isJsonPrimitive() || !value.getAsJsonPrimitive().isNumber()) throw incompatible("native-number");
            return counter(value.getAsBigDecimal().longValueExact(), minimum);
        } catch (ArithmeticException | IllegalArgumentException error) { throw incompatible("native-number"); }
    }
    public static boolean bool(JsonElement value) {
        if (value == null || !value.isJsonPrimitive() || !value.getAsJsonPrimitive().isBoolean()) throw incompatible("native-boolean");
        return value.getAsBoolean();
    }
    public static JsonObject obj(Object... pairs) {
        JsonObject object = new JsonObject();
        for (int i = 0; i < pairs.length; i += 2) object.add((String) pairs[i], json(pairs[i + 1]));
        return object;
    }
    public static JsonElement json(Object value) {
        if (value == null) return JsonNull.INSTANCE;
        if (value instanceof JsonElement v) return v;
        if (value instanceof String v) return new JsonPrimitive(v);
        if (value instanceof Boolean v) return new JsonPrimitive(v);
        if (value instanceof Number v) return new JsonPrimitive(v);
        throw new IllegalArgumentException("Unsupported internal JSON value");
    }
    public static JsonElement parse(byte[] bytes) throws IOException {
        String text = StandardCharsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(bytes)).toString();
        try (JsonReader reader = new JsonReader(new StringReader(text))) {
            reader.setStrictness(Strictness.STRICT); reader.setNestingLimit(64);
            JsonElement value = read(reader);
            if (reader.peek() != JsonToken.END_DOCUMENT) throw new IOException("Trailing JSON");
            return value;
        } catch (RuntimeException error) { throw new IOException("Invalid native JSON"); }
    }
    // Gson's tree parser otherwise accepts duplicate members. Reject ambiguity.
    private static JsonElement read(JsonReader reader) throws IOException {
        return switch (reader.peek()) {
            case BEGIN_OBJECT -> {
                reader.beginObject(); JsonObject object = new JsonObject();
                while (reader.hasNext()) {
                    String name = reader.nextName();
                    if (object.has(name)) throw new IOException("Duplicate JSON member");
                    object.add(name, read(reader));
                }
                reader.endObject(); yield object;
            }
            case BEGIN_ARRAY -> {
                reader.beginArray(); JsonArray array = new JsonArray();
                while (reader.hasNext()) array.add(read(reader));
                reader.endArray(); yield array;
            }
            case STRING -> new JsonPrimitive(reader.nextString());
            case NUMBER -> new JsonPrimitive(new java.math.BigDecimal(reader.nextString()));
            case BOOLEAN -> new JsonPrimitive(reader.nextBoolean());
            case NULL -> { reader.nextNull(); yield JsonNull.INSTANCE; }
            default -> throw new IOException("Invalid JSON value");
        };
    }
    public static JsonObject resource(String path) {
        try (InputStream input = Values.class.getResourceAsStream(path)) {
            if (input == null) throw incompatible("contract-resource");
            return object(parse(input.readAllBytes()));
        } catch (IOException error) { throw incompatible("contract-resource"); }
    }
    public static TransitException incompatible(String phase) { return new TransitException(INCOMPATIBLE_NATIVE, phase); }
    public static TransitException localIo(String phase, IOException cause) {
        var failure = new TransitException(LOCAL_IO, -1, cause.getClass().getSimpleName(), phase);
        failure.initCause(cause);
        return failure;
    }
    public static TransitException nativeError(int status, JsonElement value, String phase) {
        String code = null;
        if (value.isJsonObject()) {
            JsonObject object = value.getAsJsonObject();
            JsonElement field = object.get("protocol_error");
            if (field == null || field.isJsonNull()) field = object.get("err");
            if (field != null && field.isJsonPrimitive() && field.getAsJsonPrimitive().isString() && field.getAsString().length() <= 256) code = field.getAsString();
        }
        TransitException.Kind kind = switch (status) {
            case 3, 5 -> AUTHORITY_REJECTED; case 4 -> ACCESS_DENIED; case 6 -> UNKNOWN_OUTCOME;
            case 7, 8 -> READ_FAILED; case 9 -> BUSY; case 10 -> INCOMPATIBLE_NATIVE;
            case 11 -> STALE_OWNERSHIP; case 12 -> BLOCKED; case 13 -> TURN_EXPIRED; case 14 -> BUDGET_EXCEEDED; default -> HANDLER;
        };
        if ("ProcessExpired".equals(code) || "ProcessTerminated".equals(code)) kind = PROCESS_RETIRED;
        if ("HistoryReclaimed".equals(code) || "QueryExpired".equals(code)) kind = HISTORY_UNAVAILABLE;
        if ("StaleActivation".equals(code)) kind = STALE_OWNERSHIP;
        if (status == 6) kind = UNKNOWN_OUTCOME;
        JsonObject diagnostic = null;
        boolean invalid = false;
        JsonElement candidate = value.isJsonObject() ? value.getAsJsonObject().get("diagnostic") : null;
        if (candidate != null && !candidate.isJsonNull()) {
            try {
                JsonObject schema = resource("/io/transit/sdk/client/schemas.json").getAsJsonObject("Diagnostic");
                if (candidate.isJsonObject() && candidate.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8).length <= 32768 && Schema.valid(schema, candidate)) diagnostic = candidate.getAsJsonObject();
                else invalid = true;
            } catch (RuntimeException error) { invalid = true; }
        }
        return new TransitException(kind, status, code, phase, diagnostic, invalid);
    }
}
