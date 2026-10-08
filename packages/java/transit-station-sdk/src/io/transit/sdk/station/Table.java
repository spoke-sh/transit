package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.ResourceRef;
import io.transit.sdk.station.Types.*;
import static io.transit.client.internal.Values.*;
import static io.transit.sdk.station.Logical.fields;
import java.math.BigInteger;
import java.util.*;

/** General application-owned Tables. Each mutation step prepares one private turn. */
public final class Table {
    private static final JsonObject ACTION = resource("/io/transit/sdk/station/schemas.json").getAsJsonObject("GrowingAction");
    private static final int ACTION_BYTES = Catalog.limit("handler_action_bytes");
    private static JsonObject saved(String data, String tag) {
        text(data, ACTION_BYTES);
        int depth = 0; boolean quoted = false, escaped = false;
        for (int i = 0; i < data.length(); i++) {
            char c = data.charAt(i);
            if (quoted) { if (escaped) escaped = false; else if (c == '\\') escaped = true; else if (c == '"') quoted = false; }
            else if (c == '"') quoted = true;
            else if (c == '{' || c == '[') { if (++depth > 96) throw incompatible("saved-table-depth"); }
            else if (c == '}' || c == ']') { if (--depth < 0) throw incompatible("saved-table-depth"); }
        }
        if (quoted || depth != 0) throw incompatible("saved-table-json");
        JsonObject value = object(new Gson().fromJson(data, JsonElement.class));
        if (!value.toString().equals(data)) throw incompatible("saved-table-canonical");
        JsonObject envelope = obj("table", obj(tag, value)); text(envelope.toString(), ACTION_BYTES);
        io.transit.client.internal.Schema.require(ACTION, envelope);
        return value;
    }
    private static Bytes exact(JsonElement value, int size) {
        byte[] decoded = unhex(value, size);
        if (decoded.length != size || !HexFormat.of().formatHex(decoded).equals(string(value))) throw incompatible("table-bytes");
        return new Bytes(decoded);
    }
    private static JsonElement raw(Turn turn, String tag, JsonElement value, String expected) {
        return fields(fields(turn.raw(obj("table", obj(tag, value))), "table").get("table"), expected).get(expected);
    }
    private static void sameResource(Turn turn, JsonObject value) {
        ResourceRef expected = new ResourceRef(number(value.get("realm"), 1), number(value.get("resource"), 1));
        if (!turn.resource.equals(expected)) throw NativeValues.handlerError("foreign-table-resource");
    }
    public record RowIdentity(Bytes bytes) {
        public RowIdentity { Objects.requireNonNull(bytes); if (bytes.copy().length != 20) throw new IllegalArgumentException("Expected a 20-byte row identity"); }
        public RowIdentity(byte[] bytes) { this(new Bytes(bytes)); }
    }
    public record Row(RowIdentity identity, List<Logical.Cell> cells) {
        public Row { Objects.requireNonNull(identity); cells = Logical.owned(cells, 128); if (cells.isEmpty()) throw new IllegalArgumentException("Expected row cells"); }
    }
    public record Basis(ResourceRef resource, long revision, BigInteger object, Bytes head) {
        public Basis { Objects.requireNonNull(resource); counter(revision, 1); Catalog.positive(object); if (head.copy().length != 32) throw new IllegalArgumentException("Expected Table head digest"); }
    }
    public record Page(List<Row> rows, Optional<Cursor> next) {
        public Page { rows = Logical.owned(rows, 8); Objects.requireNonNull(next); }
    }
    public enum CreationState { BUILDING, APPLIED }
    public record Creation(CreationState state, long admittedInput, OptionalLong completedInput) {}
    public enum MutationState { BUILDING, APPLIED, REJECTED, CANCELLED }
    public enum Route { POINT, STATEMENT, ALTER }
    public enum Rejection { NONE, ROW_EXISTS, ROW_IDENTITY_EXISTS, NULL_NOT_ALLOWED, MISSING_REQUIRED_FIELD, CHARACTER_LIMIT_EXCEEDED, OVERFLOW, INEXACT }
    public enum WitnessSource { INPUT, STORED, WITHHELD }
    public record Witness(WitnessSource source, Optional<RowIdentity> row, BigInteger column, String text, boolean truncated) {}
    public record MutationStatus(Reference reference, MutationState state, Route route, long admittedInput,
        OptionalLong completedInput, Optional<Catalog.Counts> counts, Rejection rejection, Optional<Witness> witness) {}
    static MutationStatus status(JsonElement value) {
        JsonObject v = fields(value, "reference", "state", "route", "admitted_input", "completed_input", "counts", "rejection", "witness");
        MutationState state = Logical.variant(MutationState.class, v.get("state"));
        Route route = Logical.variant(Route.class, v.get("route")); Rejection rejection = Logical.variant(Rejection.class, v.get("rejection"));
        long admitted = number(v.get("admitted_input"), 1);
        OptionalLong completed = v.get("completed_input").isJsonNull() ? OptionalLong.empty() : OptionalLong.of(number(v.get("completed_input"), 1));
        if ((completed.isEmpty() != (state == MutationState.BUILDING)) || (completed.isPresent() && completed.getAsLong() < admitted) || ((rejection != Rejection.NONE) != (state == MutationState.REJECTED))) throw incompatible("table-mutation-completion");
        Optional<Catalog.Counts> counts = Optional.empty();
        if (!v.get("counts").isJsonNull()) {
            JsonObject c = fields(v.get("counts"), "matched", "changed"); counts = Optional.of(new Catalog.Counts(NativeValues.wide(c.get("matched"), false), NativeValues.wide(c.get("changed"), false)));
        }
        if (counts.isPresent() != (state == MutationState.APPLIED)) throw incompatible("table-mutation-counts");
        Optional<Witness> witness = Optional.empty();
        if (!v.get("witness").isJsonNull()) {
            JsonObject w = fields(v.get("witness"), "source", "row", "column", "text", "truncated");
            witness = Optional.of(new Witness(Logical.variant(WitnessSource.class, w.get("source")), w.get("row").isJsonNull() ? Optional.empty() : Optional.of(new RowIdentity(exact(w.get("row"), 20))),
                NativeValues.wide(w.get("column"), false), text(string(w.get("text")), 256), bool(w.get("truncated"))));
        }
        return new MutationStatus(Reference.load(v.get("reference").toString()), state, route, admitted, completed, counts, rejection, witness);
    }
    public static final class Reference {
        private final String data;
        private Reference(String data) { this.data = data; }
        public static Reference load(String data) {
            JsonObject value = saved(data, "status");
            if (!string(value.get("definition")).equals(Catalog.DEFINITION)) throw incompatible("table-definition");
            new ResourceRef(number(value.get("realm"), 1), number(value.get("resource"), 1));
            NativeValues.wide(value.get("object"), true); NativeValues.wide(value.get("operation"), true); exact(value.get("digest"), 32);
            return new Reference(data);
        }
        public String save() { return data; }
        private Optional<MutationStatus> read(Turn turn, String tag) {
            JsonObject request = object(new Gson().fromJson(data, JsonElement.class)); sameResource(turn, request);
            return turn.access(tag.equals("status"), () -> {
                JsonElement value = raw(turn, tag, request, "mutation"); if (value.isJsonNull()) return Optional.empty();
                MutationStatus result = Table.status(value);
                if (!new Gson().fromJson(result.reference().save(), JsonElement.class).equals(request)) throw incompatible("foreign-table-outcome");
                return Optional.of(result);
            });
        }
        public Optional<MutationStatus> status(Turn turn) { return read(turn, "status"); }
        public MutationStatus cancel(Turn turn) { return read(turn, "cancel").orElseThrow(() -> incompatible("missing-cancelled-table-mutation")); }
    }
    public static final class Mutation {
        private final String data;
        private Mutation(String data) { this.data = data; }
        public static Mutation prepare(ResourceRef resource, long principal, BigInteger operation, Catalog.Schema schema, Catalog.Mutation mutation) {
            Objects.requireNonNull(resource); counter(principal, 0); Catalog.positive(operation);
            return load(obj("realm", resource.realm(), "resource", resource.resource(), "principal", principal, "operation", operation.toString(), "schema", schema.wire(), "mutation", mutation.wire()).toString());
        }
        public static Mutation load(String data) {
            JsonObject value = saved(data, "mutate"); CatalogValues.schema(value.get("schema")); CatalogValues.mutation(value.get("mutation"));
            new ResourceRef(number(value.get("realm"), 1), number(value.get("resource"), 1)); NativeValues.wide(value.get("operation"), true);
            return new Mutation(data);
        }
        public String save() { return data; }
        public Catalog.Schema schema() { return CatalogValues.schema(object(new Gson().fromJson(data, JsonElement.class)).get("schema")); }
        public BigInteger operation() { return NativeValues.wide(object(new Gson().fromJson(data, JsonElement.class)).get("operation"), true); }
        public MutationStatus step(Turn turn) {
            JsonObject request = object(new Gson().fromJson(data, JsonElement.class)); sameResource(turn, request);
            return turn.access(false, () -> {
                MutationStatus result = status(raw(turn, "mutate", request, "mutation")); JsonObject identity = object(new Gson().fromJson(result.reference().save(), JsonElement.class));
                for (String key : List.of("realm", "resource", "principal", "operation")) if (!identity.get(key).equals(request.get(key))) throw incompatible("foreign-table-outcome");
                if (!identity.get("object").equals(object(request.get("schema")).get("object"))) throw incompatible("foreign-table-outcome");
                return result;
            });
        }
    }
    private final Turn turn;
    private final Catalog.Schema schema;
    private final ReadVersion version;
    private final Basis basis;
    private Table(Turn turn, Catalog.Schema schema, ReadVersion version, Basis basis) { this.turn = turn; this.schema = schema; this.version = version; this.basis = basis; }
    static Table open(Turn turn, BigInteger object, ReadVersion version) {
        Catalog.positive(object);
        JsonObject value = fields(raw(turn, "schema", obj("object", object.toString(), "version", version == null ? null : NativeValues.wire(version)), "schema"), "schema", "basis");
        Catalog.Schema schema = CatalogValues.schema(value.get("schema")); JsonObject b = fields(value.get("basis"), "resource", "revision", "object", "head");
        Basis basis = new Basis(new ResourceRef(turn.process.realm(), number(b.get("resource"), 1)), number(b.get("revision"), 1), NativeValues.wide(b.get("object"), true), exact(b.get("head"), 32));
        if (!schema.object().equals(object) || !basis.object().equals(object)) throw incompatible("foreign-table-definition");
        return new Table(turn, schema, version, basis);
    }
    static Creation create(Turn turn, Catalog.Schema schema, Catalog.TableLimits limits) {
        JsonObject value = fields(raw(turn, "create", obj("realm", turn.resource.realm(), "resource", turn.resource.resource(), "schema", schema.wire(), "limits", limits.wire()), "created"), "state", "admitted_input", "completed_input");
        CreationState state = Logical.variant(CreationState.class, value.get("state")); long admitted = number(value.get("admitted_input"), 1), completed = number(value.get("completed_input"), 0);
        if ((completed == 0) != (state == CreationState.BUILDING) || (completed != 0 && completed < admitted)) throw incompatible("table-creation-completion");
        return new Creation(state, admitted, completed == 0 ? OptionalLong.empty() : OptionalLong.of(completed));
    }
    public Catalog.Schema schema() { return schema; }
    public Basis basis() { return basis; }
    private JsonObject source() { return obj("object", schema.object().toString(), "version", version == null ? null : NativeValues.wire(version)); }
    private void checkBasis(JsonElement value) {
        JsonObject b = fields(fields(value, "schema", "basis").get("basis"), "resource", "revision", "object", "head");
        if (number(b.get("resource"), 1) != basis.resource().resource() || number(b.get("revision"), 1) != basis.revision() || !NativeValues.wide(b.get("object"), true).equals(basis.object()) || !exact(b.get("head"), 32).equals(basis.head())) throw incompatible("changed-table-basis");
    }
    private static Row row(JsonElement value) {
        JsonObject v = fields(value, "identity", "cells"); JsonArray cells = v.getAsJsonArray("cells");
        if (cells.isEmpty() || cells.size() > 128) throw incompatible("table-row-width");
        return new Row(new RowIdentity(exact(v.get("identity"), 20)), cells.asList().stream().map(Logical::cellFromWire).toList());
    }
    private Optional<Row> readRow(String tag, JsonObject request) {
        return turn.access(true, () -> {
            JsonObject value = fields(raw(turn, tag, request, "row"), "definition", "row"); checkBasis(value.get("definition"));
            return value.get("row").isJsonNull() ? Optional.empty() : Optional.of(row(value.get("row")));
        });
    }
    public Optional<Row> get(RowIdentity identity) { return readRow("get", obj("source", source(), "identity", HexFormat.of().formatHex(identity.bytes().copy()))); }
    public Optional<Row> getKey(List<Logical.Cell> key) {
        if (key.isEmpty() || key.size() > 128) throw new IllegalArgumentException("Expected primary-key cells"); JsonArray values = new JsonArray(); key.forEach(v -> values.add(Logical.cellWire(v)));
        return readRow("get_key", obj("source", source(), "key", values));
    }
    public Page page() { return page(null, 8); }
    public Page page(Cursor cursor, int limit) {
        if (limit < 1 || limit > 8) throw new IllegalArgumentException("Expected one to eight rows"); if (cursor != null) text(cursor.opaque(), 2048);
        return turn.access(true, () -> {
            JsonObject value = fields(raw(turn, "page", obj("source", source(), "cursor", cursor == null ? null : cursor.opaque(), "limit", limit), "page"), "definition", "rows", "next"); checkBasis(value.get("definition"));
            JsonArray rows = value.getAsJsonArray("rows"); if (rows.size() > limit) throw incompatible("table-page-bound");
            return new Page(rows.asList().stream().map(Table::row).toList(), Optional.ofNullable(NativeValues.cursor(value.get("next"))));
        });
    }
    public Mutation prepare(long principal, BigInteger operation, Catalog.Mutation mutation) {
        turn.check(); if (version != null) throw NativeValues.handlerError("retained-table-read-only");
        return Mutation.prepare(basis.resource(), principal, operation, schema, mutation);
    }
}
