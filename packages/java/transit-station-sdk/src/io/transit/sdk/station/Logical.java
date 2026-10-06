package io.transit.sdk.station;

import com.google.gson.*;
import static io.transit.client.internal.Values.*;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Owned logical descriptors and cells; Zig owns domain semantics and storage. */
public final class Logical {
    private Logical() {}
    private static final BigInteger U64 = BigInteger.ONE.shiftLeft(64).subtract(BigInteger.ONE);
    private static final BigInteger I128_MIN = BigInteger.ONE.shiftLeft(127).negate();
    private static final BigInteger I128_MAX = BigInteger.ONE.shiftLeft(127).subtract(BigInteger.ONE);
    private static final BigInteger U128_MAX = BigInteger.ONE.shiftLeft(128).subtract(BigInteger.ONE);
    private static final int DATA_BYTES = 1024 * 1024;
    public sealed interface Descriptor permits Scalar, Decimal, Timestamp, Structure, Union, ListType, ArrayType, MapType {}
    public enum Scalar implements Descriptor {
        INT8, INT16, INT32, INT64, INT128, UINT8, UINT16, UINT32, UINT64, UINT128,
        FLOAT32, FLOAT64, BOOLEAN, UTF8, BINARY, DATE, TIME, INTERVAL, UUID, JSON
    }
    public enum Kind {
        INT8, INT16, INT32, INT64, INT128, UINT8, UINT16, UINT32, UINT64, UINT128,
        FLOAT32, FLOAT64, DECIMAL, BOOLEAN, UTF8, BINARY, DATE, TIME, TIMESTAMP,
        INTERVAL, UUID, STRUCTURE, TAGGED_UNION, LIST, ARRAY, MAP, JSON
    }
    public enum Zone { CIVIL, UTC }
    public record Decimal(int precision, int scale) implements Descriptor {
        public Decimal { if (precision < 1 || precision > 38 || scale < 0 || scale > precision) throw invalid("decimal descriptor"); }
    }
    public record Timestamp(Zone zone) implements Descriptor { public Timestamp { Objects.requireNonNull(zone); } }
    public record Field(String name, Descriptor type, boolean nullable, boolean optional) {
        public Field { text(name, 4096); Objects.requireNonNull(type); }
        public Field(String name, Descriptor type) { this(name, type, false, false); }
    }
    public record Element(Descriptor type, boolean nullable) {
        public Element { Objects.requireNonNull(type); }
        public Element(Descriptor type) { this(type, false); }
    }
    public record Structure(List<Field> fields) implements Descriptor { public Structure { fields = owned(fields, 256); } }
    public record Union(List<Field> fields) implements Descriptor { public Union { fields = owned(fields, 256); } }
    public record ListType(Element element) implements Descriptor { public ListType { Objects.requireNonNull(element); } }
    public record ArrayType(Element element, long length) implements Descriptor {
        public ArrayType { Objects.requireNonNull(element); bounded(length, 1, 0xffffffffL); }
    }
    public record MapType(Descriptor key, Element value) implements Descriptor {
        public MapType { Objects.requireNonNull(key); Objects.requireNonNull(value); }
    }
    /** Binary data is copied on construction and access; equality compares bytes. */
    public static final class BinaryData {
        private final byte[] data;
        public BinaryData(byte[] data) { this.data = bytes(data, DATA_BYTES); }
        public byte[] copy() { return data.clone(); }
        public int size() { return data.length; }
        @Override public boolean equals(Object other) { return other instanceof BinaryData value && Arrays.equals(data, value.data); }
        @Override public int hashCode() { return Arrays.hashCode(data); }
        @Override public String toString() { return "BinaryData[length=" + data.length + "]"; }
    }
    public sealed interface Value permits Atom, Sequence, MapValue, Tagged, Json {}
    public sealed interface Atom extends Value permits Signed, Unsigned, DecimalValue, Float32, Float64, BooleanValue, Utf8, Binary, Uuid, DateDays, TimeNanos, TimestampMicros, Interval {}
    public record Signed(BigInteger value) implements Atom { public Signed { exact(value, I128_MIN, I128_MAX); } }
    public record Unsigned(BigInteger value) implements Atom { public Unsigned { exact(value, BigInteger.ZERO, U128_MAX); } }
    public record DecimalValue(BigInteger value) implements Atom { public DecimalValue { exact(value, I128_MIN, I128_MAX); } }
    public record Float32(float value) implements Atom { public Float32 { if (!Float.isFinite(value)) throw invalid("nonfinite float32"); } }
    public record Float64(double value) implements Atom { public Float64 { if (!Double.isFinite(value)) throw invalid("nonfinite float64"); } }
    public record BooleanValue(boolean value) implements Atom {}
    public record Utf8(String value) implements Atom { public Utf8 { text(value, DATA_BYTES); } }
    public record Binary(BinaryData value) implements Atom { public Binary { Objects.requireNonNull(value); } }
    public record Uuid(BinaryData value) implements Atom { public Uuid { if (value.size() != 16) throw invalid("UUID width"); } }
    public record DateDays(int value) implements Atom {}
    public record TimeNanos(BigInteger value) implements Atom { public TimeNanos { exact(value, BigInteger.ZERO, U64); } }
    public record TimestampMicros(long value) implements Atom {}
    public record Interval(int months, int days, long nanos) implements Atom {}
    public enum SequenceKind { STRUCTURE, LIST, ARRAY }
    public record Sequence(SequenceKind kind, List<Cell> cells) implements Value {
        public Sequence { Objects.requireNonNull(kind); cells = owned(cells, 65536); }
    }
    public record MapEntry(Atom key, Cell value) { public MapEntry { Objects.requireNonNull(key); Objects.requireNonNull(value); } }
    public record MapValue(List<MapEntry> entries) implements Value { public MapValue { entries = owned(entries, 32767); } }
    public record Tagged(int index, Cell value) implements Value { public Tagged { bounded(index, 0, 255); Objects.requireNonNull(value); } }
    public record Json(String json) implements Value { public Json { text(json, DATA_BYTES); } }
    public sealed interface Cell permits Missing, Null, SourceTypeError, Present, Conflict {}
    public record Missing() implements Cell {}
    public record Null() implements Cell {}
    public record SourceTypeError(Kind actual) implements Cell { public SourceTypeError { Objects.requireNonNull(actual); } }
    public record Present(Value value) implements Cell { public Present { Objects.requireNonNull(value); } }
    public record Alternative(BigInteger counter, BigInteger replica, Cell value) {
        public Alternative {
            exact(counter, BigInteger.ONE, U64); exact(replica, BigInteger.ONE, U64);
            if (!(value instanceof Null || value instanceof SourceTypeError || value instanceof Present)) throw invalid("conflict alternative");
        }
    }
    public record Conflict(List<Alternative> alternatives) implements Cell {
        public Conflict {
            alternatives = owned(alternatives, 8);
            if (alternatives.size() < 2) throw invalid("conflict count");
            for (int i = 1; i < alternatives.size(); i++) {
                Alternative a = alternatives.get(i - 1), b = alternatives.get(i);
                int order = a.counter().compareTo(b.counter());
                if (order > 0 || (order == 0 && a.replica().compareTo(b.replica()) >= 0)) throw invalid("conflict dot order");
            }
        }
    }
    private static IllegalArgumentException invalid(String what) { return new IllegalArgumentException("Invalid logical " + what); }
    private static long bounded(long value, long minimum, long maximum) {
        if (value < minimum || value > maximum) throw invalid("integer bound"); return value;
    }
    static BigInteger exact(BigInteger value, BigInteger minimum, BigInteger maximum) {
        Objects.requireNonNull(value);
        if (value.compareTo(minimum) < 0 || value.compareTo(maximum) > 0) throw invalid("integer bound"); return value;
    }
    static <T> List<T> owned(List<T> values, int maximum) {
        if (values.size() > maximum) throw invalid("collection bound"); return List.copyOf(values);
    }
    static String tag(Enum<?> value) { return Objects.requireNonNull(value).name().toLowerCase(Locale.ROOT); }
    static <E extends Enum<E>> E variant(Class<E> type, JsonElement value) {
        String name = string(value); E result = Enum.valueOf(type, name.toUpperCase(Locale.ROOT));
        if (!tag(result).equals(name)) throw invalid("variant"); return result;
    }
    static JsonObject fields(JsonElement value, String... names) {
        JsonObject result = object(value);
        if (!result.keySet().equals(Set.of(names))) throw invalid("fields"); return result;
    }
    private static Map.Entry<String, JsonElement> variant(JsonElement value) {
        JsonObject result = object(value);
        if (result.size() != 1) throw invalid("variant count"); return result.entrySet().iterator().next();
    }
    private static final class Budget {
        private final int maximum;
        private int nodes, data, names;
        Budget(int maximum) { this.maximum = maximum; }
        void enter(int depth) { if (depth >= 16 || ++nodes > maximum) throw invalid("depth/child bound"); }
        void data(int length) { data += length; if (data > DATA_BYTES) throw invalid("aggregate data bound"); }
        String name(String value) { text(value, 4096); names += value.getBytes(StandardCharsets.UTF_8).length; if (names > 4096) throw invalid("aggregate name bound"); return value; }
    }
    public static JsonObject typeWire(Descriptor value) { return typeWire(value, new Budget(256), 0); }
    private static JsonObject elementWire(Element value, Budget budget, int depth) {
        return obj("type", typeWire(value.type(), budget, depth + 1), "nullable", value.nullable());
    }
    private static JsonObject typeWire(Descriptor value, Budget budget, int depth) {
        budget.enter(depth);
        return switch (value) {
            case Scalar scalar -> obj(tag(scalar), obj());
            case Decimal decimal -> obj("decimal", obj("precision", decimal.precision(), "scale", decimal.scale()));
            case Timestamp timestamp -> obj("timestamp", tag(timestamp.zone()));
            case Structure structure -> obj("structure", fieldsWire(structure.fields(), budget, depth));
            case Union union -> obj("tagged_union", fieldsWire(union.fields(), budget, depth));
            case ListType list -> obj("list", elementWire(list.element(), budget, depth));
            case ArrayType array -> obj("array", obj("element", elementWire(array.element(), budget, depth), "length", array.length()));
            case MapType map -> obj("map", obj("key", typeWire(map.key(), budget, depth + 1), "value", elementWire(map.value(), budget, depth)));
        };
    }
    private static JsonArray fieldsWire(List<Field> fields, Budget budget, int depth) {
        JsonArray result = new JsonArray();
        for (Field field : fields) result.add(obj("name", budget.name(field.name()), "type", typeWire(field.type(), budget, depth + 1), "nullable", field.nullable(), "optional", field.optional()));
        return result;
    }
    public static Descriptor typeFromWire(JsonElement value) { return typeFromWire(value, new Budget(256), 0); }
    private static Element elementFromWire(JsonElement value, Budget budget, int depth) {
        JsonObject v = fields(value, "type", "nullable"); return new Element(typeFromWire(v.get("type"), budget, depth + 1), bool(v.get("nullable")));
    }
    private static Descriptor typeFromWire(JsonElement value, Budget budget, int depth) {
        budget.enter(depth); var entry = variant(value); String kind = entry.getKey(); JsonElement payload = entry.getValue();
        for (Scalar scalar : Scalar.values()) if (tag(scalar).equals(kind)) { fields(payload); return scalar; }
        switch (kind) {
            case "decimal": {
                JsonObject v = fields(payload, "precision", "scale"); return new Decimal(Math.toIntExact(number(v.get("precision"), 1)), Math.toIntExact(number(v.get("scale"), 0)));
            }
            case "timestamp": return new Timestamp(variant(Zone.class, payload));
            case "structure", "tagged_union": {
                List<Field> fields = new ArrayList<>();
                for (JsonElement item : payload.getAsJsonArray()) {
                    JsonObject v = fields(item, "name", "type", "nullable", "optional");
                    fields.add(new Field(budget.name(string(v.get("name"))), typeFromWire(v.get("type"), budget, depth + 1), bool(v.get("nullable")), bool(v.get("optional"))));
                }
                return kind.equals("structure") ? new Structure(fields) : new Union(fields);
            }
            case "list": return new ListType(elementFromWire(payload, budget, depth));
            case "array": {
                JsonObject v = fields(payload, "element", "length"); return new ArrayType(elementFromWire(v.get("element"), budget, depth), number(v.get("length"), 1));
            }
            case "map": {
                JsonObject v = fields(payload, "key", "value"); return new MapType(typeFromWire(v.get("key"), budget, depth + 1), elementFromWire(v.get("value"), budget, depth));
            }
            default: throw invalid("descriptor variant");
        }
    }
    public static JsonObject atomWire(Atom value) { return atomWire(value, new Budget(65536)); }
    private static JsonObject atomWire(Atom value, Budget budget) {
        return switch (value) {
            case Signed v -> obj("signed", v.value().toString());
            case Unsigned v -> obj("unsigned", v.value().toString());
            case DecimalValue v -> obj("decimal", v.value().toString());
            case Float32 v -> { budget.data(4); yield obj("float_bits", HexFormat.of().formatHex(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putFloat(v.value()).array())); }
            case Float64 v -> { budget.data(8); yield obj("float_bits", HexFormat.of().formatHex(ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putDouble(v.value()).array())); }
            case BooleanValue v -> obj("boolean", v.value());
            case Utf8 v -> { budget.data(v.value().getBytes(StandardCharsets.UTF_8).length); yield obj("utf8", v.value()); }
            case Binary v -> { budget.data(v.value().size()); yield obj("binary", HexFormat.of().formatHex(v.value().data)); }
            case Uuid v -> { budget.data(v.value().size()); yield obj("uuid", HexFormat.of().formatHex(v.value().data)); }
            case DateDays v -> obj("date_days", Integer.toString(v.value()));
            case TimeNanos v -> obj("time_nanos", v.value().toString());
            case TimestampMicros v -> obj("timestamp_micros", Long.toString(v.value()));
            case Interval v -> obj("interval", obj("months", Integer.toString(v.months()), "days", Integer.toString(v.days()), "nanos", Long.toString(v.nanos())));
        };
    }
    private static BigInteger decimal(JsonElement value, BigInteger minimum, BigInteger maximum) {
        String text = string(value);
        if (text.length() > 40 || !text.matches("0|-?[1-9][0-9]*")) throw invalid("canonical integer");
        return exact(new BigInteger(text), minimum, maximum);
    }
    private static BigInteger integer(JsonElement value) { return decimal(value, I128_MIN, U128_MAX); }
    public static Atom atomFromWire(JsonElement value) { return atomFromWire(value, new Budget(65536)); }
    private static Atom atomFromWire(JsonElement value, Budget budget) {
        var entry = variant(value); String kind = entry.getKey(); JsonElement payload = entry.getValue();
        return switch (kind) {
            case "signed" -> new Signed(integer(payload));
            case "unsigned" -> new Unsigned(integer(payload));
            case "decimal" -> new DecimalValue(integer(payload));
            case "date_days" -> new DateDays(integer(payload).intValueExact());
            case "time_nanos" -> new TimeNanos(integer(payload));
            case "timestamp_micros" -> new TimestampMicros(integer(payload).longValueExact());
            case "boolean" -> new BooleanValue(bool(payload));
            case "utf8" -> { String text = string(payload); budget.data(text.getBytes(StandardCharsets.UTF_8).length); yield new Utf8(text); }
            case "binary", "uuid", "float_bits" -> {
                byte[] bytes = unhex(payload, kind.equals("float_bits") ? 8 : kind.equals("uuid") ? 16 : DATA_BYTES); budget.data(bytes.length);
                if (kind.equals("binary")) yield new Binary(new BinaryData(bytes));
                if (kind.equals("uuid")) yield new Uuid(new BinaryData(bytes));
                ByteBuffer bits = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN);
                if (bytes.length == 4) yield new Float32(bits.getFloat());
                if (bytes.length == 8) yield new Float64(bits.getDouble());
                throw invalid("float width");
            }
            case "interval" -> {
                JsonObject v = fields(payload, "months", "days", "nanos"); yield new Interval(integer(v.get("months")).intValueExact(), integer(v.get("days")).intValueExact(), integer(v.get("nanos")).longValueExact());
            }
            default -> throw invalid("atom variant");
        };
    }
    public static JsonObject cellWire(Cell value) { return cellWire(value, new Budget(65536), 0); }
    private static JsonObject cellWire(Cell value, Budget budget, int depth) {
        budget.enter(depth);
        return switch (value) {
            case Missing ignored -> obj("missing", obj());
            case Null ignored -> obj("null", obj());
            case SourceTypeError error -> obj("type_error", tag(error.actual()));
            case Conflict conflict -> {
                JsonArray alternatives = new JsonArray();
                for (Alternative a : conflict.alternatives()) alternatives.add(obj("counter", a.counter().toString(), "replica", a.replica().toString(), "value", cellWire(a.value(), budget, depth)));
                yield obj("conflict", alternatives);
            }
            case Present present -> obj("value", valueWire(present.value(), budget, depth));
        };
    }
    private static JsonObject valueWire(Value value, Budget budget, int depth) {
        return switch (value) {
            case Atom atom -> obj("atom", atomWire(atom, budget));
            case Sequence sequence -> {
                JsonArray cells = new JsonArray(); for (Cell child : sequence.cells()) cells.add(cellWire(child, budget, depth + 1)); yield obj(tag(sequence.kind()), cells);
            }
            case MapValue map -> {
                JsonArray entries = new JsonArray();
                for (MapEntry entry : map.entries()) { budget.enter(depth + 1); entries.add(obj("key", atomWire(entry.key(), budget), "value", cellWire(entry.value(), budget, depth + 1))); }
                yield obj("map", entries);
            }
            case Tagged tagged -> obj("tagged_union", obj("index", tagged.index(), "value", cellWire(tagged.value(), budget, depth + 1)));
            case Json json -> { budget.data(json.json().getBytes(StandardCharsets.UTF_8).length); yield obj("json", json.json()); }
        };
    }
    public static Cell cellFromWire(JsonElement value) { return cellFromWire(value, new Budget(65536), 0); }
    private static Cell cellFromWire(JsonElement value, Budget budget, int depth) {
        budget.enter(depth); var entry = variant(value); String kind = entry.getKey(); JsonElement payload = entry.getValue();
        return switch (kind) {
            case "missing" -> { fields(payload); yield new Missing(); }
            case "null" -> { fields(payload); yield new Null(); }
            case "type_error" -> new SourceTypeError(variant(Kind.class, payload));
            case "conflict" -> {
                JsonArray values = payload.getAsJsonArray(); if (values.size() < 2 || values.size() > 8) throw invalid("conflict count");
                List<Alternative> alternatives = new ArrayList<>();
                for (JsonElement item : values) {
                    JsonObject v = fields(item, "counter", "replica", "value"); alternatives.add(new Alternative(decimal(v.get("counter"), BigInteger.ONE, U64), decimal(v.get("replica"), BigInteger.ONE, U64), cellFromWire(v.get("value"), budget, depth)));
                }
                yield new Conflict(alternatives);
            }
            case "value" -> new Present(valueFromWire(payload, budget, depth));
            default -> throw invalid("cell variant");
        };
    }
    private static Value valueFromWire(JsonElement value, Budget budget, int depth) {
        var entry = variant(value); String kind = entry.getKey(); JsonElement payload = entry.getValue();
        return switch (kind) {
            case "atom" -> atomFromWire(payload, budget);
            case "structure", "list", "array" -> {
                List<Cell> cells = new ArrayList<>(); for (JsonElement item : payload.getAsJsonArray()) cells.add(cellFromWire(item, budget, depth + 1));
                yield new Sequence(SequenceKind.valueOf(kind.toUpperCase(Locale.ROOT)), cells);
            }
            case "map" -> {
                List<MapEntry> entries = new ArrayList<>();
                for (JsonElement item : payload.getAsJsonArray()) { budget.enter(depth + 1); JsonObject v = fields(item, "key", "value"); entries.add(new MapEntry(atomFromWire(v.get("key"), budget), cellFromWire(v.get("value"), budget, depth + 1))); }
                yield new MapValue(entries);
            }
            case "tagged_union" -> {
                JsonObject v = fields(payload, "index", "value"); yield new Tagged(Math.toIntExact(number(v.get("index"), 0)), cellFromWire(v.get("value"), budget, depth + 1));
            }
            case "json" -> { String text = string(payload); budget.data(text.getBytes(StandardCharsets.UTF_8).length); yield new Json(text); }
            default -> throw invalid("value variant");
        };
    }
}
