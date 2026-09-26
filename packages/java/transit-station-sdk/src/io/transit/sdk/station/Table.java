package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.TransitException;
import io.transit.sdk.station.Types.*;
import static io.transit.client.internal.Values.*;
import java.util.*;

public final class Table<T> {
    /** Closed family of supported native cells; nullability belongs to Row. */
    public static final class Cell<T> {
        private final String name;
        private final Class<T> type;
        private Cell(String name, Class<T> type) { this.name = name; this.type = type; }
        public String wireName() { return name; }
        JsonObject encode(T value, int bound) {
            if (value == null) return obj("null", obj());
            if (!type.isInstance(value)) throw new IllegalArgumentException("Wrong Table cell type");
            Object encoded = switch (name) {
                case "int64" -> Long.toString((Long) value);
                case "boolean" -> value;
                case "utf8" -> text((String) value, bound);
                case "binary" -> HexFormat.of().formatHex(bytes(((Bytes) value).copy(), bound));
                default -> throw new IllegalStateException("Unknown cell");
            };
            return obj(name, encoded);
        }
        T decode(JsonElement wire, int bound) {
            JsonObject value = object(wire);
            if (value.has("null")) return null;
            if (!value.has(name)) throw incompatible("table-cell-type");
            Object decoded = switch (name) {
                case "int64" -> NativeValues.signed(value.get(name));
                case "boolean" -> bool(value.get(name));
                case "utf8" -> text(string(value.get(name)), bound);
                case "binary" -> new Bytes(unhex(value.get(name), bound));
                default -> throw new IllegalStateException("Unknown cell");
            };
            return type.cast(decoded);
        }
    }
    public static final Cell<Long> INT64 = new Cell<>("int64", Long.class);
    public static final Cell<Boolean> BOOLEAN = new Cell<>("boolean", Boolean.class);
    public static final Cell<String> UTF8 = new Cell<>("utf8", String.class);
    public static final Cell<Bytes> BINARY = new Cell<>("binary", Bytes.class);
    public record Schema<T>(long id, Cell<T> cell, String keyName, String valueName) {
        public Schema {
            if (id < 1 || id > 0xffffffffL) throw new IllegalArgumentException("Table ID exceeds its bound");
            Objects.requireNonNull(cell); text(keyName, 256); text(valueName, 256);
        }
        public Schema(long id, Cell<T> cell) { this(id, cell, "id", "value"); }
    }
    public record Row<T>(long key, T value) {}
    private final Turn turn;
    private final Schema<T> schema;
    private final ReadVersion version;
    private final Basis basis;
    private Table(Turn turn, Schema<T> schema, ReadVersion version, Basis basis) { this.turn = turn; this.schema = schema; this.version = version; this.basis = basis; }
    static <T> Table<T> open(Turn turn, Schema<T> schema, ReadVersion version) {
        Objects.requireNonNull(schema);
        JsonObject request = obj("id", schema.id());
        if (version != null) request.add("version", NativeValues.wire(version));
        JsonObject actual = object(turn.raw(obj("table_schema", request)).get("schema"));
        if (!string(actual.get("key_name")).equals(schema.keyName()) || !string(actual.get("value_name")).equals(schema.valueName()) ||
            !string(actual.get("value_type")).equals(schema.cell().wireName())) throw new TransitException(TransitException.Kind.HANDLER, -1, "TableSchemaChanged", "table-schema");
        return new Table<>(turn, schema, version, NativeValues.basis(actual.get("basis"), turn.process.realm()));
    }
    public Schema<T> schema() { return schema; }
    public Basis basis() { return basis; }
    private JsonObject request() {
        JsonObject result = obj("id", schema.id());
        if (version != null) result.add("version", NativeValues.wire(version));
        return result;
    }
    private Row<T> row(JsonElement wire) {
        JsonObject value = object(wire);
        return new Row<>(NativeValues.signed(value.get("key")), schema.cell().decode(value.get("value"), turn.limit("table_cell_bytes")));
    }
    public Optional<Row<T>> get(long key) {
        return turn.access(true, () -> {
            JsonObject request = request(); request.addProperty("key", Long.toString(key));
            JsonElement value = turn.raw(obj(version == null ? "table_get" : "version_table_get", request)).get("row");
            return value.isJsonNull() ? Optional.empty() : Optional.of(row(value));
        });
    }
    public void insert(Row<T> row) { write("insert", row); }
    public void update(Row<T> row) { write("update", row); }
    public void upsert(Row<T> row) { write("upsert", row); }
    private void writable() { if (version != null) throw NativeValues.handlerError("retained-table-read-only"); }
    private void write(String mode, Row<T> row) {
        turn.access(false, () -> {
            writable(); Objects.requireNonNull(row);
            turn.raw(obj("table_write", obj("id", schema.id(), "mode", mode, "row", obj("key", Long.toString(row.key()), "value", schema.cell().encode(row.value(), turn.limit("table_cell_bytes"))))));
            return null;
        });
    }
    public void delete(long key) {
        turn.access(false, () -> { writable(); turn.raw(obj("table_delete", obj("id", schema.id(), "key", Long.toString(key)))); return null; });
    }
    public Page<Row<T>> page() { return page(null); }
    public Page<Row<T>> page(Cursor cursor) {
        return turn.access(true, () -> {
            JsonObject request = request(); request.add("cursor", json(cursor == null ? null : cursor.opaque()));
            JsonObject result = object(turn.raw(obj("table_page", request)).get("rows"));
            List<Row<T>> rows = new ArrayList<>();
            for (JsonElement value : result.getAsJsonArray("rows")) if (!value.isJsonNull()) rows.add(row(value));
            return new Page<>(rows, NativeValues.cursor(result.get("next")), NativeValues.basis(result.get("basis"), turn.process.realm()));
        });
    }
}
