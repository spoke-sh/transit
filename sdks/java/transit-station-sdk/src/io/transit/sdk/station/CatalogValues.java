package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import static io.transit.client.internal.Values.*;
import static io.transit.sdk.station.Logical.fields;
import static io.transit.sdk.station.Logical.variant;
import static io.transit.sdk.station.Catalog.*;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.function.Function;
import java.util.function.Supplier;

/** Strict owned decoding of the shared Table contract. */
final class CatalogValues {
    private CatalogValues() {}
    static <T> T decode(Supplier<T> work) {
        try { return work.get(); }
        catch (TransitException error) { throw error; }
        catch (RuntimeException error) { throw incompatible("catalog-response"); }
    }
    static JsonElement result(JsonElement value, String key) { return fields(value, key).get(key); }
    static <T> Optional<T> optional(JsonElement value, Function<JsonElement, T> decode) { return value.isJsonNull() ? Optional.empty() : Optional.of(decode.apply(value)); }
    static BigInteger wide(JsonElement value) { return NativeValues.wide(value, true); }
    static BigInteger zero(JsonElement value) { return NativeValues.wide(value, false); }
    static Scope scope(JsonElement value) {
        JsonObject v = fields(value, "realm", "resource", "catalog"); return new Scope(new ResourceRef(number(v.get("realm"), 1), number(v.get("resource"), 1)), wide(v.get("catalog")));
    }
    static AuthorityProfile authority(JsonElement value) {
        JsonObject v = fields(value, "database_domain", "schema_domain", "table_domain", "stream_domain", "queue_domain", "kv_domain", "database", "initial_schema", "initial_schema_authority");
        return new AuthorityProfile(number(v.get("database_domain"), 1), number(v.get("schema_domain"), 1), number(v.get("table_domain"), 1),
            number(v.get("stream_domain"), 1), number(v.get("queue_domain"), 1), number(v.get("kv_domain"), 1), number(v.get("database"), 1), number(v.get("initial_schema"), 1), number(v.get("initial_schema_authority"), 1));
    }
    static Subject subject(JsonElement value) {
        JsonObject v = fields(value, "principal", "login_role", "role", "credential_epoch", "audience", "context");
        return new Subject(number(v.get("principal"), 0), number(v.get("login_role"), 0), number(v.get("role"), 0),
            number(v.get("credential_epoch"), 1), number(v.get("audience"), 1), NativeValues.digest(v.get("context")));
    }
    static Schema schema(JsonElement value) {
        JsonObject v = fields(value, "definition", "object", "revision", "next_column", "columns", "primary_key"); Catalog.definition(string(v.get("definition")));
        JsonArray cols = v.getAsJsonArray("columns"), keys = v.getAsJsonArray("primary_key");
        if (cols.isEmpty() || cols.size() > 128 || keys.size() > cols.size()) throw incompatible("catalog-schema-bound");
        List<Column> columns = new ArrayList<>();
        for (JsonElement col : cols) {
            JsonObject c = fields(col, "id", "name", "type", "nullable", "default", "max_characters", "encoding", "collation");
            columns.add(new Column(wide(c.get("id")), string(c.get("name")), Logical.typeFromWire(c.get("type")), bool(c.get("nullable")), optional(c.get("default"), Logical::cellFromWire), optional(c.get("max_characters"), n -> number(n, 1)), variant(Encoding.class, c.get("encoding")), variant(Collation.class, c.get("collation"))));
        }
        Schema result = new Schema(wide(v.get("object")), wide(v.get("revision")), wide(v.get("next_column")), columns, keys.asList().stream().map(CatalogValues::wide).toList());
        result.wire(); return result;
    }
    private static List<Assignment> assignments(JsonElement value) {
        JsonArray array = value.getAsJsonArray();
        if (array.size() > 128) throw incompatible("catalog-assignment-bound");
        return array.asList().stream().map(item -> {
            JsonObject v = fields(item, "column", "value"), cell = object(v.get("value"));
            if (cell.has("default")) { fields(fields(cell, "default").get("default")); return new Assignment(wide(v.get("column")), Default.VALUE); }
            return new Assignment(wide(v.get("column")), Logical.cellFromWire(fields(cell, "cell").get("cell")));
        }).toList();
    }
    private static Predicate predicate(JsonElement value) {
        JsonObject v = object(value);
        if (v.has("atom")) {
            JsonObject atom = object(fields(v, "atom").get("atom"));
            if (atom.has("all")) { fields(fields(atom, "all").get("all")); return BooleanOperator.ALL; }
            if (atom.has("state")) {
                JsonObject state = fields(fields(atom, "state").get("state"), "column", "value");
                return new StatePredicate(wide(state.get("column")), variant(CellState.class, state.get("value")));
            }
            JsonObject compare = fields(fields(atom, "compare").get("compare"), "column", "op", "value");
            return new Comparison(wide(compare.get("column")), variant(CompareOperator.class, compare.get("op")), Logical.atomFromWire(compare.get("value")));
        }
        if (v.size() != 1) throw incompatible("catalog-predicate");
        String tag = v.keySet().iterator().next(); fields(v.get(tag));
        BooleanOperator result = variant(BooleanOperator.class, new JsonPrimitive(tag));
        if (result == BooleanOperator.ALL) throw incompatible("catalog-predicate");
        return result;
    }
    static Mutation mutation(JsonElement value) {
        JsonObject v = fields(value, "action", "predicate"), action = object(v.get("action"));
        Optional<List<Predicate>> predicates = optional(v.get("predicate"), p -> {
            JsonArray array = p.getAsJsonArray(); if (array.size() > 64) throw incompatible("catalog-predicate-bound");
            return array.asList().stream().map(CatalogValues::predicate).toList();
        });
        if (action.size() != 1) throw incompatible("catalog-mutation");
        Mutation result;
        if (action.has("insert")) {
            JsonArray rows = action.getAsJsonArray("insert");
            if (predicates.isPresent() || rows.isEmpty() || rows.size() > 1024) throw incompatible("catalog-insert-bound");
            result = new Insert(rows.asList().stream().map(CatalogValues::assignments).toList());
        } else if (action.has("update")) result = new Update(assignments(action.get("update")), predicates);
        else { fields(fields(action, "delete").get("delete")); result = new Delete(predicates); }
        if (!result.wire().equals(value)) throw incompatible("catalog-mutation-canonical");
        return result;
    }
    private static final JsonObject SCHEMAS = resource("/io/transit/sdk/station/schemas.json");
    static JsonObject parseSaved(String data) {
        text(data, limit("catalog_action_bytes"));
        try { return object(io.transit.client.internal.Values.parse(data.getBytes(StandardCharsets.UTF_8), 96)); }
        catch (java.io.IOException error) { throw new IllegalArgumentException("Invalid saved catalog binding", error); }
    }
    static void action(JsonObject value) { io.transit.client.internal.Schema.require(SCHEMAS.getAsJsonObject("CatalogAction"), value); }
    static void response(JsonObject value) { io.transit.client.internal.Schema.require(SCHEMAS.getAsJsonObject("CatalogResult"), value); }
    static JsonElement path(JsonElement value, String... fields) { for (String field : fields) value = result(value, field); return value; }
    static String tag(JsonObject value) { if (value.size() != 1) throw incompatible("catalog-variant"); return value.keySet().iterator().next(); }
    static Bytes digestHex(JsonElement value) { return digest(new Bytes(unhex(value, 32))); }
    static Connection connection(JsonElement value) {
        JsonObject v = fields(value, "scope", "branch", "audience", "principal", "role"); number(v.get("principal"), 0);
        return new Connection(scope(v.get("scope")), number(v.get("audience"), 1), wide(v.get("branch")), optional(v.get("role"), item -> number(item, 0)));
    }
    static ObjectIdentity objectIdentity(JsonElement value) { JsonObject v = object(value); return new ObjectIdentity(scope(v.get("scope")), wide(v.get("branch")), wide(v.get("object"))); }
    static Interpretation interpretation(JsonElement value) { JsonObject v = object(value); return new Interpretation(objectIdentity(v.get("object")), wide(v.get("revision")), digestHex(v.get("digest"))); }
    static Content content(JsonElement value) { JsonObject v = object(value); return new Content(wide(v.get("bytes")), digestHex(v.get("sha256"))); }
    static StoredDefinition stored(JsonElement value) { JsonObject v = object(value); return new StoredDefinition(interpretation(v.get("interpretation")), content(v.get("content")), digestHex(v.get("schema_fingerprint")), bool(v.get("retired"))); }
    static Position position(JsonElement value) { JsonObject v = object(value); return new Position(wide(v.get("partition")), zero(v.get("next_lsn"))); }
    static void owns(Connection c, ObjectIdentity target) { if (!c.scope().equals(target.scope()) || !c.branch().equals(target.branch())) throw new IllegalArgumentException("Foreign catalog object"); }
    static void checkBinding(JsonObject value, Connection c, long principal) {
        definition(string(value.get("definition"))); JsonObject identity = value.getAsJsonObject("identity"); wide(identity.get("operation"));
        ObjectIdentity target = objectIdentity(value.get("target")); owns(c, target); digestHex(value.get("intent"));
        if (!scope(identity.get("scope")).equals(c.scope()) || number(identity.get("principal"), 0) != principal) throw new IllegalArgumentException("Foreign original caller");
        Optional<Interpretation> expected = optional(value.get("expected_definition"), CatalogValues::interpretation);
        if (expected.isPresent() && !expected.get().object().equals(target)) throw new IllegalArgumentException("Foreign expected interpretation");
        optional(value.get("expected_data"), CatalogValues::position);
        if (string(value.get("action")).equals("create") ? expected.isPresent() || !value.get("expected_data").isJsonNull() : expected.isEmpty()) throw new IllegalArgumentException("Invalid definition expectations");
    }
    static void assertion(JsonObject value) {
        definition(string(value.get("definition"))); Connection c = connection(value.get("connection"));
        number(value.get("namespace"), 1); name(string(value.get("name"))); wide(value.get("operation")); digestHex(value.get("intent"));
        Optional<Interpretation> expected = optional(value.get("expected"), CatalogValues::interpretation); expected.ifPresent(v -> owns(c, v.object()));
        if (string(value.get("action")).equals("create_if_not_exists") != expected.isPresent()) throw new IllegalArgumentException("Invalid name assertion");
    }
    static Capabilities capabilities(JsonElement value) {
        JsonObject v = object(value); definition(string(v.get("definition")));
        Capabilities c = new Capabilities(Math.toIntExact(number(v.get("version"), 1)), DEFINITION, Math.toIntExact(number(v.get("max_columns"), 1)), Math.toIntExact(number(v.get("max_rows"), 1)),
            Math.toIntExact(number(v.get("max_sql_bytes"), 1)), Math.toIntExact(number(v.get("max_intent_bytes"), 1)), Math.toIntExact(number(v.get("max_action_bytes"), 1)),
            Math.toIntExact(number(v.get("metadata_page_entries"), 1)), Math.toIntExact(number(v.get("resident_intents"), 1)));
        if (c.version() != 1 || c.maxColumns() != 128 || c.maxRows() != 1024 || c.maxSqlBytes() != 4096 || c.maxIntentBytes() != limit("catalog_intent_bytes") ||
            c.maxActionBytes() != limit("catalog_action_bytes") || c.metadataPageEntries() != 8 || c.residentIntents() != 1) throw new TransitException(TransitException.Kind.UNSUPPORTED_CAPABILITY, "catalog-capabilities");
        return c;
    }
    static Description description(JsonElement value, Connection c, long principal) {
        JsonObject v = object(value), raw = v.getAsJsonObject("configuration");
        Configuration config = new Configuration(scope(raw.get("scope")), wide(raw.get("branch")), wide(raw.get("partition")), number(raw.get("audience"), 1), authority(raw.get("authority")),
            name(string(raw.get("database_name"))), name(string(raw.get("initial_schema_name"))));
        Subject subject = subject(v.get("subject"));
        if (!config.scope().equals(c.scope()) || !config.branch().equals(c.branch()) || config.audience() != c.audience() || subject.principal() != principal ||
            subject.audience() != c.audience() || c.role().filter(role -> role != subject.role()).isPresent()) throw incompatible("catalog-description");
        return new Description(config, subject, number(v.get("policy_revision"), 0));
    }
    static Namespace namespace(JsonElement value) {
        JsonObject v = object(value); return new Namespace(scope(v.get("scope")), number(v.get("id"), 1), number(v.get("authorization"), 1), name(string(v.get("name"))), number(v.get("revision"), 1), bool(v.get("retired")));
    }
    private static <T> Page<T> page(JsonElement value, Connection c, long principal, JsonObject selection, Optional<Cursor> previous, Function<JsonElement,T> decode, Function<T,BigInteger> identity) {
        JsonObject v = object(value); Position position = position(v.get("position")); List<T> entries = new ArrayList<>(); boolean ended = false;
        BigInteger after = previous.map(Cursor::after).orElse(BigInteger.ZERO);
        for (JsonElement raw : v.getAsJsonArray("entries")) {
            if (raw.isJsonNull()) { ended = true; continue; }
            if (ended) throw incompatible("catalog-page-hole");
            T entry = decode.apply(raw); BigInteger id = identity.apply(entry);
            if (id.compareTo(after) <= 0) throw incompatible("catalog-page-order"); after = id; entries.add(entry);
        }
        Optional<Cursor> next = optional(v.get("next"), item -> Cursor.restore(item.toString()));
        if (next.isPresent()) {
            Cursor cursor = next.get(); cursor.check(c, principal, selection);
            if (!cursor.position().equals(position) || cursor.after().compareTo(after) < 0 || cursor.after().compareTo(previous.map(Cursor::after).orElse(BigInteger.ZERO)) <= 0) throw incompatible("catalog-page-continuation");
        }
        if (previous.isPresent() && !previous.get().position().equals(position)) throw incompatible("catalog-directory-changed");
        return new Page<>(position, entries, next, selection.has("tables") ? Optional.of(Consistency.INDEPENDENT) : Optional.empty());
    }
    static Page<Namespace> namespaces(JsonElement value, Connection c, long principal, Optional<Cursor> previous) {
        return page(value, c, principal, obj("namespaces", obj()), previous, raw -> {
            Namespace found = namespace(raw); if (!found.scope().equals(c.scope())) throw incompatible("catalog-namespace-scope"); return found;
        }, item -> BigInteger.valueOf(item.id()));
    }
    static Page<Entry> tables(JsonElement value, Connection c, long principal, long namespace, Optional<Cursor> previous) {
        return page(value, c, principal, obj("tables", namespace), previous, raw -> {
            JsonObject v = object(raw); Interpretation interpretation = interpretation(v.get("interpretation")); owns(c, interpretation.object());
            long ns = number(v.get("namespace"), 1); if (ns != namespace) throw incompatible("catalog-page-namespace");
            return new Entry(interpretation, ns, name(string(v.get("name"))), position(v.get("position")), zero(v.get("changed_lsn")));
        }, item -> item.interpretation().object().object());
    }
    static Metadata metadata(JsonElement value, Connection c, long principal, long namespace, String name) {
        JsonObject v = object(value); Basis basis = Basis.restore(v.get("binding").toString()); Schema schema = schema(v.get("schema"));
        if (!basis.connection().equals(c) || basis.principal() != principal || basis.namespace() != namespace || !basis.name().equals(name) || !basis.object().equals(schema.object())) throw incompatible("catalog-lookup-identity");
        return new Metadata(basis, number(v.get("authorization"), 1), position(v.get("position")), zero(v.get("changed_lsn")), zero(v.get("row_count")), schema);
    }
    static Intent summary(JsonElement value, SavedIntent saved, Connection c, long principal, Identity expected) {
        JsonObject v = object(value), id = v.getAsJsonObject("id"), tagged = v.getAsJsonObject("binding"); definition(string(id.get("definition"))); digestHex(id.get("digest"));
        long namespace = number(v.get("namespace"), 1); String kind = tag(tagged); JsonObject binding = tagged.getAsJsonObject(kind); BigInteger operation;
        if (kind.equals("table")) { checkBinding(binding, c, principal); operation = wide(binding.getAsJsonObject("identity").get("operation")); }
        else {
            assertion(binding); operation = wide(binding.get("operation"));
            if (!binding.get("connection").equals(c.wire(principal)) || number(binding.get("namespace"), 1) != namespace) throw incompatible("catalog-name-binding");
        }
        Identity identity = new Identity(operation, namespace);
        if (expected != null && !expected.equals(identity)) throw incompatible("catalog-prepared-identity");
        JsonObject savedWire = saved.wire(); if (!savedWire.has(kind)) throw incompatible("catalog-saved-kind"); JsonObject raw = savedWire.getAsJsonObject(kind);
        if (number(raw.get("namespace"), 1) != namespace || (kind.equals("name_assertion") && !raw.equals(binding))) throw incompatible("catalog-saved-binding");
        return new Intent(id, binding, Logical.variant(WorkKind.class, new JsonPrimitive(kind)), identity, saved);
    }
    static ObservationKind expectedKind(WorkKind kind, JsonObject binding) {
        return kind == WorkKind.NAME_ASSERTION ? ObservationKind.NAME_ASSERTION : Set.of("insert", "update", "delete").contains(string(binding.get("action"))) ? ObservationKind.ROWS : ObservationKind.DDL;
    }
    static Observation observation(JsonElement value, Reference original) {
        JsonObject tagged = object(value); String kind = tag(tagged); JsonObject state = tagged.getAsJsonObject(kind); String tag = tag(state); JsonObject raw = state.getAsJsonObject(tag);
        ObservationKind observedKind = variant(ObservationKind.class, new JsonPrimitive(kind));
        if (observedKind != expectedKind(original.kind(), original.binding())) throw incompatible("catalog-observation-kind");
        if (tag.equals("not_observed")) return new Observation(observedKind, OperationState.NOT_OBSERVED, original, Optional.empty(), Optional.empty(), Optional.empty(), Optional.empty());
        if (!raw.get("binding").equals(original.binding())) throw incompatible("catalog-original-binding");
        if (observedKind == ObservationKind.NAME_ASSERTION) return new Observation(observedKind, variant(OperationState.class, raw.get("state")), original, Optional.empty(), Optional.empty(), Optional.of(variant(Reason.class, raw.get("reason"))), Optional.of(position(raw.get("position"))));
        if (tag.equals("committed")) {
            StoredDefinition stored = stored(raw.get("resulting")); JsonObject outcome = raw.getAsJsonObject("outcome");
            BigInteger matched = zero(outcome.get("matched")), affected = zero(outcome.get("affected"));
            if (affected.compareTo(matched) > 0 || !stored.interpretation().object().equals(objectIdentity(original.binding().get("target")))) throw incompatible("catalog-commit-evidence");
            Commit commit = new Commit(stored, position(outcome.get("position")), matched, affected, zero(outcome.get("live_rows")));
            return new Observation(observedKind, OperationState.COMMITTED, original, Optional.of(commit), Optional.empty(), Optional.empty(), Optional.empty());
        }
        content(raw.get("intent")); String phase = string(raw.get("phase"));
        if (tag.equals("admitted") ? !Set.of("admitted", "ready", "settled").contains(phase) : !tag.equals(phase)) throw incompatible("catalog-operation-phase");
        if (observedKind == ObservationKind.ROWS) { JsonObject basis = raw.getAsJsonObject("basis"); interpretation(basis.get("interpretation")); position(basis.get("position")); zero(basis.get("changed_lsn")); }
        return new Observation(observedKind, variant(OperationState.class, new JsonPrimitive(tag)), original, Optional.empty(), Optional.of(variant(Phase.class, raw.get("phase"))), Optional.of(variant(Reason.class, raw.get("reason"))), Optional.empty());
    }
    static Preview preview(JsonElement value, Intent intent) {
        JsonObject tagged = object(value); String kind = tag(tagged); JsonObject raw = tagged.getAsJsonObject(kind);
        ObservationKind observed = variant(ObservationKind.class, new JsonPrimitive(kind));
        if (observed != expectedKind(intent.kind(), intent.binding()) || !raw.get("binding").equals(intent.binding())) throw incompatible("catalog-preview-binding");
        if (observed == ObservationKind.NAME_ASSERTION) return new Preview(observed, intent, position(raw.get("position")), optional(raw.get("current"), v -> new CurrentName(interpretation(v))), Optional.empty(), Optional.empty(), Optional.empty(), Optional.empty(), Optional.of(bool(raw.get("matches"))));
        Optional<PreviewCurrent> current = optional(raw.get("current"), item -> {
            JsonObject v = object(item); return new CurrentBasis(stored(v.get("interpretation")), position(v.get("position")), zero(v.get("changed_lsn")), zero(v.get("row_count")));
        });
        boolean ddl = observed == ObservationKind.DDL;
        return new Preview(observed, intent, position(raw.get("directory_position")), current, Optional.of(variant(Reason.class, raw.get("reason"))),
            ddl ? optional(raw.get("work"), v -> variant(EvolutionWork.class, v)) : Optional.empty(), ddl ? Optional.of(bool(raw.get("rebuild_key"))) : Optional.empty(),
            ddl ? optional(raw.get("schema_fingerprint"), CatalogValues::digestHex) : Optional.empty(), Optional.empty());
    }
    static ReadAuthority readAuthority(JsonElement value) {
        JsonObject v = object(value); return new ReadAuthority(number(v.get("database"), 1), number(v.get("schema"), 1), number(v.get("table"), 1));
    }
    static SnapshotStatus snapshotStatus(JsonElement value, SnapshotOwner owner) {
        JsonObject v = object(value); Interpretation current = interpretation(v.get("current_interpretation"));
        if (!v.get("owner").equals(owner.wire()) || !current.object().equals(owner.object())) throw incompatible("catalog-retention-owner");
        Optional<Snapshot> snapshot = optional(v.get("snapshot"), s -> Snapshot.restore(s.toString()));
        if (snapshot.isPresent() && !snapshot.get().owner().equals(owner)) throw incompatible("catalog-original-snapshot");
        return new SnapshotStatus(owner, current, position(v.get("current_position")), bool(v.get("retired")), snapshot, bool(v.get("released")), readAuthority(v.get("authority")));
    }
    static SnapshotMetadata snapshotMetadata(JsonElement value, Snapshot snapshot) {
        JsonObject v = object(value); StoredDefinition stored = stored(v.get("interpretation")); Schema schema = schema(v.get("schema"));
        if (!v.get("snapshot").equals(snapshot.wire()) || !stored.interpretation().object().equals(snapshot.owner().object()) || !schema.object().equals(snapshot.owner().object().object())) throw incompatible("catalog-retained-definition");
        return new SnapshotMetadata(snapshot, stored, position(v.get("accepted")), zero(v.get("changed_lsn")), zero(v.get("row_count")), schema, readAuthority(v.get("authority")));
    }
}
