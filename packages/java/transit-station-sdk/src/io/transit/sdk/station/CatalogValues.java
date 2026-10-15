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
    private static final JsonObject DIAGNOSTIC = resource("/io/transit/sdk/client/schemas.json").getAsJsonObject("Diagnostic");
    static <T> T decode(Supplier<T> work) {
        try { return work.get(); }
        catch (TransitException error) { throw error; }
        catch (RuntimeException error) { throw incompatible("catalog-response"); }
    }
    static JsonElement result(JsonElement value, String key) { return fields(value, key).get(key); }
    private static <T> Optional<T> optional(JsonElement value, Function<JsonElement, T> decode) { return value.isJsonNull() ? Optional.empty() : Optional.of(decode.apply(value)); }
    private static BigInteger wide(JsonElement value) { return NativeValues.wide(value, true); }
    private static BigInteger zero(JsonElement value) { return NativeValues.wide(value, false); }
    static JsonObject diagnostic(JsonElement value) {
        JsonObject out = object(value); text(out.toString(), 32768);
        io.transit.client.internal.Schema.require(DIAGNOSTIC, out); return out.deepCopy();
    }
    static Scope scope(JsonElement value) {
        JsonObject v = fields(value, "realm", "resource", "catalog"); return new Scope(new ResourceRef(number(v.get("realm"), 1), number(v.get("resource"), 1)), wide(v.get("catalog")));
    }
    static Configuration configuration(JsonElement value) {
        JsonObject v = fields(value, "scope", "owner", "administrator", "table_limits", "authority", "database_name"), limits = fields(v.get("table_limits"), "record_bytes", "staging_bytes", "staging_records"); Scope scope = scope(v.get("scope"));
        return new Configuration(scope, new ProcessRef(scope.resource().realm(), number(v.get("owner"), 1)), number(v.get("administrator"), 0), new TableLimits(number(limits.get("record_bytes"), 1), wide(limits.get("staging_bytes")), number(limits.get("staging_records"), 1)), authority(v.get("authority")), string(v.get("database_name")));
    }
    static AuthorityProfile authority(JsonElement value) {
        JsonObject v = fields(value, "database_domain", "schema_domain", "table_domain", "database", "initial_schema", "initial_schema_authority");
        return new AuthorityProfile(number(v.get("database_domain"), 1), number(v.get("schema_domain"), 1), number(v.get("table_domain"), 1),
            number(v.get("database"), 1), number(v.get("initial_schema"), 1), number(v.get("initial_schema_authority"), 1));
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
            JsonObject c = fields(col, "id", "name", "type", "nullable", "default", "max_characters");
            columns.add(new Column(wide(c.get("id")), string(c.get("name")), Logical.typeFromWire(c.get("type")), bool(c.get("nullable")), optional(c.get("default"), Logical::cellFromWire), optional(c.get("max_characters"), n -> number(n, 1))));
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
    static MetadataCommitment commitment(JsonElement value) {
        JsonObject v=fields(value,"format","length","digest");
        if(number(v.get("format"),1)!=0x54434d01)throw incompatible("catalog-metadata-format");
        return new MetadataCommitment(Math.toIntExact(number(v.get("length"),1)),NativeValues.digest(v.get("digest")));
    }
    static Metadata metadata(JsonElement value) {
        JsonObject v = fields(value, "namespace", "scope", "object", "revision", "name", "schema_fingerprint", "principal", "operation", "admitted_input", "commitment");
        return new Metadata(scope(v.get("scope")), number(v.get("namespace"), 1), wide(v.get("object")), wide(v.get("revision")), string(v.get("name")), new Bytes(unhex(v.get("schema_fingerprint"), 32)), number(v.get("principal"), 0), wide(v.get("operation")), number(v.get("admitted_input"), 1),commitment(v.get("commitment")));
    }
    static Head head(JsonElement value) { JsonObject v = fields(value, "revision", "rows", "pending"); return new Head(wide(v.get("revision")), zero(v.get("rows")), zero(v.get("pending"))); }
    static Optional<Definition> resolved(JsonElement value, Scope scope, long namespace, String name) {
        return optional(value, item -> {
            JsonObject v = fields(item, "authorization", "metadata", "head", "schema"); Definition out = new Definition(number(v.get("authorization"), 1), metadata(v.get("metadata")), head(v.get("head")), schema(v.get("schema")));
            if (!out.metadata().scope().equals(scope) || out.metadata().namespace() != namespace || !out.metadata().name().equals(name) || !out.schema().object().equals(out.metadata().object())) throw incompatible("catalog-definition-identity"); return out;
        });
    }
    static Optional<HistoricalDefinition> historical(JsonElement value, Scope scope, BigInteger object, BigInteger revision) {
        return optional(value, item -> {
            JsonObject v = fields(item, "metadata", "schema"); HistoricalDefinition out = new HistoricalDefinition(metadata(v.get("metadata")), schema(v.get("schema")));
            if (!out.metadata().scope().equals(scope) || !out.metadata().object().equals(object) || !out.metadata().revision().equals(revision) || !out.schema().object().equals(object)) throw incompatible("catalog-historical-identity"); return out;
        });
    }
    static Optional<Cursor> cursor(JsonElement value) {
        return optional(value, item -> { JsonObject v = fields(item, "definition", "scope", "resource_revision", "after_object"); return new Cursor(string(v.get("definition")), scope(v.get("scope")), number(v.get("resource_revision"), 0), wide(v.get("after_object"))); });
    }
    static Page page(JsonElement value, Scope scope, Optional<Cursor> previous) {
        JsonObject v = fields(value, "resource_revision", "entries", "next"); JsonArray slots = v.getAsJsonArray("entries");
        if (slots.size() != 8) throw incompatible("catalog-page-slots");
        List<Entry> entries = new ArrayList<>(); boolean ended = false;
        for (JsonElement slot : slots) {
            if (slot.isJsonNull()) ended = true;
            else {
                JsonObject entry = fields(slot, "metadata", "head"); Entry decoded = new Entry(metadata(entry.get("metadata")), head(entry.get("head")));
                if (ended || !decoded.metadata().scope().equals(scope)) throw incompatible("catalog-page-scope"); entries.add(decoded);
            }
        }
        Page page = new Page(number(v.get("resource_revision"), 0), entries, cursor(v.get("next")));
        if (page.next().isPresent() && !page.next().get().scope().equals(scope)) throw incompatible("catalog-cursor-scope");
        if (previous.isPresent()) {
            Cursor c = previous.get();
            if (page.resourceRevision() != c.resourceRevision() || (!entries.isEmpty() && entries.getFirst().metadata().object().compareTo(c.afterObject()) <= 0) || (page.next().isPresent() && page.next().get().afterObject().compareTo(c.afterObject()) <= 0)) throw incompatible("catalog-page-continuation");
        }
        return page;
    }
    static Intent intent(JsonElement value, Connection connection, long principal) {
        JsonObject v = fields(value, "reference", "scope", "owner", "principal", "operation", "namespace", "object", "kind"), r = fields(v.get("reference"), "definition", "digest"); Scope scope = scope(v.get("scope"));
        Intent out = new Intent(new Reference(string(r.get("definition")), new Bytes(unhex(r.get("digest"), 32))), scope, new ProcessRef(scope.resource().realm(), number(v.get("owner"), 1)), number(v.get("principal"), 0), new Identity(wide(v.get("operation")), wide(v.get("namespace"))), zero(v.get("object")), variant(Kind.class, v.get("kind")));
        if (!out.scope().equals(connection.scope()) || !out.owner().equals(connection.owner()) || out.principal() != principal) throw incompatible("catalog-intent-connection"); return out;
    }
    static Compiled compiled(JsonElement value, Connection connection, long principal, Identity identity, Kind kind, BigInteger object) {
        JsonObject v = fields(value, "intent", "saved"), saved = fields(v.get("saved"), "definition", "bytes");
        Compiled out = new Compiled(intent(v.get("intent"), connection, principal), new SavedIntent(string(saved.get("definition")), unhex(saved.get("bytes"), limit("catalog_intent_bytes"))));
        if (!out.intent().identity().equals(identity) || (kind != null && out.intent().kind() != kind) || (object != null && !out.intent().object().equals(object))) throw incompatible("catalog-compiled-identity"); return out;
    }
    static Optional<Outcome> outcome(JsonElement value) {
        return optional(value, item -> {
            JsonObject v = fields(item, "kind", "operation", "object", "actual_object", "phase", "terminal", "counts", "admitted_input", "completed_input", "diagnostic");
            Kind kind = variant(Kind.class, v.get("kind")); Phase phase = variant(Phase.class, v.get("phase")); boolean terminal = bool(v.get("terminal"));
            Optional<Counts> counts = optional(v.get("counts"), c -> { JsonObject n = fields(c, "matched", "changed"); return new Counts(zero(n.get("matched")), zero(n.get("changed"))); });
            if (terminal != EnumSet.of(Phase.APPLIED, Phase.UNCHANGED, Phase.REJECTED, Phase.CANCELLED).contains(phase)) throw incompatible("catalog-terminal");
            if (counts.isPresent() != (phase == Phase.APPLIED && EnumSet.of(Kind.INSERT, Kind.UPDATE, Kind.DELETE).contains(kind))) throw incompatible("catalog-counts");
            return new Outcome(kind, wide(v.get("operation")), zero(v.get("object")), optional(v.get("actual_object"), CatalogValues::zero), phase, terminal, counts, number(v.get("admitted_input"), 1), optional(v.get("completed_input"), p -> number(p, 1)), object(v.get("diagnostic")));
        });
    }
    static Optional<Upload> upload(JsonElement value) {
        return optional(value, item -> {
            JsonObject v = fields(item, "phase", "received", "total"); long total = number(v.get("total"), 1), received = number(v.get("received"), 0);
            if (received > total || total > limit("catalog_intent_bytes")) throw incompatible("catalog-upload-bounds");
            return new Upload(variant(UploadPhase.class, v.get("phase")), (int)received, (int)total);
        });
    }
    static Catalog.State state(JsonElement value) { JsonObject v = fields(value, "outcome", "upload"); return new Catalog.State(outcome(v.get("outcome")), upload(v.get("upload"))); }
    static Optional<Disposition> disposition(JsonElement value) {
        return optional(value, item -> { JsonObject v = fields(item, "input", "outcome", "diagnostic"); return new Disposition(number(v.get("input"), 1), variant(DispositionOutcome.class, v.get("outcome")), object(v.get("diagnostic"))); });
    }
    static Prepared prepared(JsonElement value) { return new Prepared(new Bytes(text(string(value), limit("catalog_prepared_bytes")).getBytes(StandardCharsets.UTF_8))); }
    static Next next(JsonElement value) {
        JsonObject v = object(value); if (v.size() != 1) throw incompatible("catalog-next"); var entry = v.entrySet().iterator().next();
        switch (entry.getKey()) {
            case "send": return new Next(NextKind.SEND, Optional.of(prepared(entry.getValue())), Optional.empty());
            case "terminal": {
                Optional<Outcome> out = outcome(entry.getValue()); if (out.isEmpty() || !out.get().terminal()) throw incompatible("catalog-terminal");
                return new Next(NextKind.TERMINAL, Optional.empty(), out);
            }
            case "running", "upload_cancelled": fields(entry.getValue()); return new Next(entry.getKey().equals("running") ? NextKind.RUNNING : NextKind.UPLOAD_CANCELLED, Optional.empty(), Optional.empty());
            default: throw incompatible("catalog-next");
        }
    }
    static Progress progress(JsonElement value) {
        JsonObject v = object(value); if (v.size() != 1) throw incompatible("catalog-progress");
        if (v.has("pending")) { fields(v.get("pending")); return new Progress(Observation.PENDING, Optional.empty(), Optional.empty(), Optional.empty()); }
        JsonObject p = fields(result(v, "processed"), "disposition", "outcome", "upload"); return new Progress(Observation.PROCESSED, disposition(p.get("disposition")), outcome(p.get("outcome")), upload(p.get("upload")));
    }
    static Capabilities capabilities(JsonElement value) {
        JsonObject v = fields(value, "version", "definition", "max_columns", "max_rows", "max_sql_bytes", "max_intent_bytes", "max_action_bytes", "max_prepared_bytes", "resident_intents"); Catalog.definition(string(v.get("definition")));
        return new Capabilities(Math.toIntExact(number(v.get("version"), 1)), DEFINITION, Math.toIntExact(number(v.get("max_columns"), 1)), Math.toIntExact(number(v.get("max_rows"), 1)), Math.toIntExact(number(v.get("max_sql_bytes"), 1)), Math.toIntExact(number(v.get("max_intent_bytes"), 1)), Math.toIntExact(number(v.get("max_action_bytes"), 1)), Math.toIntExact(number(v.get("max_prepared_bytes"), 1)), Math.toIntExact(number(v.get("resident_intents"), 1)));
    }
    static boolean supported(Capabilities c) {
        return c.version() == 1 && c.maxColumns() == 128 && c.maxRows() == 1024 && c.maxSqlBytes() == 4096 && c.maxIntentBytes() == limit("catalog_intent_bytes") && c.maxActionBytes() == limit("catalog_action_bytes") && c.maxPreparedBytes() == limit("catalog_prepared_bytes") && c.residentIntents() == 1;
    }
    static Description description(JsonElement value, Connection connection, long principal) {
        JsonObject v = fields(value, "configuration", "subject", "authorization_revision", "resource_revision"); Description out = new Description(configuration(v.get("configuration")), subject(v.get("subject")), number(v.get("authorization_revision"), 0), number(v.get("resource_revision"), 0));
        if (!out.configuration().scope().equals(connection.scope()) || !out.configuration().owner().equals(connection.owner()) || out.subject().principal() != principal || out.subject().audience() != connection.owner().pid() || connection.role().filter(role -> role != out.subject().role()).isPresent()) throw incompatible("catalog-description"); return out;
    }
}
