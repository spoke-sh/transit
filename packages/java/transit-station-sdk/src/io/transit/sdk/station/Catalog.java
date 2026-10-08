package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import io.transit.client.internal.Worker;
import static io.transit.client.internal.Values.*;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.function.Function;
import java.util.function.Supplier;

/** General Tables; shared Zig owns compilation, authority and durable recovery. */
public final class Catalog {
    private Catalog() {}
    static final JsonObject CONTRACT = resource("/io/transit/sdk/station/contract.json");
    public static final String DEFINITION = string(CONTRACT.get("definition"));
    static int limit(String name) { return CONTRACT.getAsJsonObject("limits").get(name).getAsInt(); }
    static BigInteger positive(BigInteger value) { u64(value); if (value.signum() == 0) throw new IllegalArgumentException("Expected positive Table identity"); return value; }
    static String name(String value) { text(value, 255); if (value.isEmpty() || value.indexOf(0) >= 0) throw new IllegalArgumentException("Invalid Table name"); return value; }
    static String definition(String value) { if (!DEFINITION.equals(value)) throw new IllegalArgumentException("Missing or foreign Table definition"); return value; }
    static Bytes digest(Bytes value) { if (value.size() != 32) throw new IllegalArgumentException("Expected digest"); return value; }
    static String hex(Bytes value) { return HexFormat.of().formatHex(value.copy()); }
    static long u32(long value) { if (value < 1 || value > 0xffffffffL) throw new IllegalArgumentException("Expected positive uint32"); return value; }
    public enum Kind { CREATE, ALTER, RENAME, DROP, INSERT, UPDATE, DELETE }
    public enum Phase { PREPARING, DELEGATED, BUILDING, APPLIED, UNCHANGED, REJECTED, CANCELLED }
    public enum Observation { PENDING, PROCESSED }
    public enum UploadPhase { UPLOADING, SEALED, READY, CANCELLED }
    public enum DispositionOutcome { INITIALIZED, POLICY_APPLIED, DEPENDENCY_APPLIED, INVALID_COMMAND, BLOCKED, DENIED, IDENTITY_CONFLICT, STALE_POLICY }
    public enum Control { CANCEL_OPERATION, CLEANUP_OPERATION, CANCEL_UPLOAD, COLLECT_UPLOAD }
    public enum DependencyKind { QUERY_SOURCE, WRITER, WATCH, MAINTAINED_RELATION, HISTORY }
    public record Scope(ResourceRef resource, BigInteger catalog) {
        public Scope { Objects.requireNonNull(resource); positive(catalog); }
        JsonObject wire() { return obj("realm", resource.realm(), "resource", resource.resource(), "catalog", catalog.toString()); }
    }
    public record Connection(ProcessRef owner, Scope scope) {
        public Connection { Objects.requireNonNull(owner); Objects.requireNonNull(scope); if (owner.realm() != scope.resource().realm()) throw new IllegalArgumentException("Catalog requires one realm"); }
        JsonObject wire(Credential identity) {
            if (identity.realm() != owner.realm()) throw new IllegalArgumentException("Different credential realm");
            return obj("scope", scope.wire(), "owner", owner.pid(), "principal", identity.principal());
        }
    }
    public record TableLimits(long recordBytes, BigInteger stagingBytes, long stagingRecords) {
        public TableLimits { u32(recordBytes); positive(stagingBytes); u32(stagingRecords); if (stagingBytes.compareTo(BigInteger.valueOf(recordBytes)) < 0) throw new IllegalArgumentException("Staging quota cannot hold a record"); }
        JsonObject wire() { return obj("record_bytes", recordBytes, "staging_bytes", stagingBytes.toString(), "staging_records", stagingRecords); }
    }
    public record Configuration(Scope scope, ProcessRef owner, long administrator, TableLimits tableLimits) {
        public Configuration { new Connection(owner, scope); counter(administrator, 1); Objects.requireNonNull(tableLimits); }
        JsonObject wire() { return obj("scope", scope.wire(), "owner", owner.pid(), "administrator", administrator, "table_limits", tableLimits.wire()); }
    }
    public record Rights(boolean inspect, boolean create, boolean read, boolean insert, boolean update, boolean delete, boolean alter, boolean drop) {
        JsonObject wire() { return obj("inspect", inspect, "create", create, "read", read, "insert", insert, "update", update, "delete", delete, "alter", alter, "drop", drop); }
    }
    public record Policy(Scope scope, long principal, BigInteger revision, Rights rights) {
        public Policy { Objects.requireNonNull(scope); counter(principal, 0); positive(revision); Objects.requireNonNull(rights); }
        JsonObject wire() { JsonObject out = obj("scope", scope.wire(), "principal", principal, "revision", revision.toString()); rights.wire().entrySet().forEach(e -> out.add(e.getKey(), e.getValue())); return out; }
    }
    public record PolicyChange(BigInteger expectedRevision, Policy policy) {
        public PolicyChange { u64(expectedRevision); Objects.requireNonNull(policy); if (!policy.revision().equals(expectedRevision.add(BigInteger.ONE))) throw new IllegalArgumentException("Expected successor policy revision"); }
        JsonObject wire() { return obj("expected_revision", expectedRevision.toString(), "policy", policy.wire()); }
    }
    private static final class WireBudget {
        private int remaining;
        WireBudget(int limit) { remaining = limit; }
        JsonObject take(JsonObject value) {
            remaining -= value.toString().getBytes(StandardCharsets.UTF_8).length;
            if (remaining < 0) throw new IllegalArgumentException("Table wire budget exceeded");
            return value;
        }
    }
    public record Column(BigInteger id, String name, Logical.Descriptor type, boolean nullable, Optional<Logical.Cell> defaultValue, Optional<Long> maxCharacters) {
        public Column { positive(id); Catalog.name(name); Objects.requireNonNull(type); Objects.requireNonNull(defaultValue); maxCharacters.ifPresent(Catalog::u32); }
        public Column(BigInteger id, String name, Logical.Descriptor type) { this(id, name, type, true, Optional.empty(), Optional.empty()); }
        JsonObject wire() { JsonObject out = columnWire(name, type, nullable, defaultValue, maxCharacters); out.addProperty("id", id.toString()); return out; }
    }
    static JsonObject columnWire(String name, Logical.Descriptor type, boolean nullable, Optional<Logical.Cell> defaultValue, Optional<Long> maxCharacters) {
        return obj("name", name, "type", Logical.typeWire(type), "nullable", nullable, "default", defaultValue.map(Logical::cellWire).orElse(null), "max_characters", maxCharacters.orElse(null));
    }
    public record Schema(BigInteger object, BigInteger revision, BigInteger nextColumn, List<Column> columns, List<BigInteger> primaryKey) {
        public Schema {
            positive(object); positive(revision); positive(nextColumn); columns = Logical.owned(columns, 128); primaryKey = Logical.owned(primaryKey, columns.size());
            if (columns.isEmpty()) throw new IllegalArgumentException("Expected Table columns"); primaryKey.forEach(Catalog::positive);
        }
        public Schema(BigInteger object, BigInteger revision, BigInteger nextColumn, List<Column> columns) { this(object, revision, nextColumn, columns, List.of()); }
        JsonObject wire() {
            WireBudget budget = new WireBudget(2 * 1024 * 1024);
            JsonArray cols = new JsonArray(), keys = new JsonArray(); columns.forEach(c -> cols.add(budget.take(c.wire()))); primaryKey.forEach(k -> keys.add(k.toString()));
            JsonObject result = obj("definition", DEFINITION, "object", object.toString(), "revision", revision.toString(), "next_column", nextColumn.toString(), "columns", cols, "primary_key", keys);
            text(result.toString(), 2 * 1024 * 1024); return result;
        }
    }
    public record Identity(BigInteger operation, BigInteger namespace) {
        public Identity { positive(operation); positive(namespace); }
        JsonObject wire() { return obj("operation", operation.toString(), "namespace", namespace.toString()); }
    }
    public record Basis(BigInteger object, BigInteger revision, Bytes schemaFingerprint) {
        public Basis { positive(object); positive(revision); digest(schemaFingerprint); }
        JsonObject wire() { return obj("object", object.toString(), "revision", revision.toString(), "schema_fingerprint", hex(schemaFingerprint)); }
    }
    public record MetadataCommitment(int bytes,Bytes digest) {
        public MetadataCommitment { if(bytes<1 || bytes>436)throw new IllegalArgumentException("Invalid Table metadata length"); Catalog.digest(digest); }
        JsonObject wire() { JsonArray data=new JsonArray(); for(byte b:digest.copy())data.add(Byte.toUnsignedInt(b)); return obj("format",0x54434d01,"length",bytes,"digest",data); }
    }
    public record Metadata(Scope scope, BigInteger object, BigInteger revision, String name, Bytes schemaFingerprint, long principal, BigInteger operation, long admittedInput, MetadataCommitment commitment) {
        public Metadata { Objects.requireNonNull(scope); positive(object); positive(revision); Catalog.name(name); digest(schemaFingerprint); counter(principal, 0); positive(operation); counter(admittedInput, 1); Objects.requireNonNull(commitment); }
        public Basis basis() { return new Basis(object, revision, schemaFingerprint); }
    }
    public record Head(BigInteger revision, BigInteger rows, BigInteger pending) { public Head { positive(revision); u64(rows); u64(pending); } }
    public record Entry(Metadata metadata, Head head) { public Entry { Objects.requireNonNull(metadata); Objects.requireNonNull(head); } }
    public record Definition(Metadata metadata, Head head, Schema schema) {}
    public record HistoricalDefinition(Metadata metadata, Schema schema) {}
    public record Cursor(String definition, Scope scope, long resourceRevision, BigInteger afterObject) {
        public Cursor { Catalog.definition(definition); Objects.requireNonNull(scope); counter(resourceRevision, 0); positive(afterObject); }
        JsonObject wire() { return obj("definition", definition, "scope", scope.wire(), "resource_revision", resourceRevision, "after_object", afterObject.toString()); }
    }
    public record Page(long resourceRevision, List<Entry> entries, Optional<Cursor> next) {
        public Page {
            counter(resourceRevision, 0); entries = Logical.owned(entries, 8); Objects.requireNonNull(next);
            for (int i = 1; i < entries.size(); i++) {
                Metadata a = entries.get(i - 1).metadata(), b = entries.get(i).metadata();
                if (!a.scope().equals(b.scope()) || a.object().compareTo(b.object()) >= 0) throw new IllegalArgumentException("Unordered or foreign Table entries");
            }
            if (next.isPresent()) {
                Cursor c = next.get(); Metadata last = entries.isEmpty() ? null : entries.getLast().metadata();
                if (c.resourceRevision() != resourceRevision || (last != null && (!c.scope().equals(last.scope()) || c.afterObject().compareTo(last.object()) < 0))) throw new IllegalArgumentException("Invalid Table continuation");
            }
        }
    }
    public record Reference(String definition, Bytes digest) {
        public Reference { Catalog.definition(definition); Catalog.digest(digest); }
        JsonObject wire() { return obj("definition", definition, "digest", hex(digest)); }
    }
    /** Persist both fields unchanged before sending a step. */
    public record SavedIntent(String definition, byte[] bytes) {
        public SavedIntent { Catalog.definition(definition); bytes = io.transit.client.internal.Values.bytes(bytes, limit("catalog_intent_bytes")); if (bytes.length == 0) throw new IllegalArgumentException("Empty Table intent"); }
        @Override public byte[] bytes() { return bytes.clone(); }
        @Override public boolean equals(Object other) { return other instanceof SavedIntent saved && definition.equals(saved.definition) && Arrays.equals(bytes, saved.bytes); }
        @Override public int hashCode() { return 31 * definition.hashCode() + Arrays.hashCode(bytes); }
        @Override public String toString() { return "SavedIntent[owned recovery bytes=" + bytes.length + "]"; }
        JsonObject wire() { return obj("definition", definition, "bytes", HexFormat.of().formatHex(bytes)); }
    }
    public record Prepared(Bytes bytes) {
        public Prepared { Objects.requireNonNull(bytes); if (bytes.size() == 0 || bytes.size() > limit("catalog_prepared_bytes")) throw new IllegalArgumentException("Invalid prepared Table length"); text(bytes.copy()); }
        String wire() { return text(bytes.copy()); }
        @Override public String toString() { return "Prepared[owned signed command]"; }
    }
    public record Intent(Reference reference, Scope scope, ProcessRef owner, long principal, Identity identity, BigInteger object, Kind kind) {}
    public record Compiled(Intent intent, SavedIntent saved) {}
    public record Counts(BigInteger matched, BigInteger changed) {
        public Counts { u64(matched); u64(changed); if (changed.compareTo(matched) > 0) throw new IllegalArgumentException("Changed exceeds matched"); }
    }
    public record Outcome(Kind kind, BigInteger operation, BigInteger object, Optional<BigInteger> actualObject, Phase phase, boolean terminal, Optional<Counts> counts, long admittedInput, Optional<Long> completedInput, JsonObject diagnostic) {
        public Outcome { diagnostic = CatalogValues.diagnostic(diagnostic); }
        @Override public JsonObject diagnostic() { return diagnostic.deepCopy(); }
    }
    public record Upload(UploadPhase phase, int received, int total) {}
    public record State(Optional<Outcome> outcome, Optional<Upload> upload) {}
    public record Disposition(long input, DispositionOutcome outcome, JsonObject diagnostic) {
        public Disposition { diagnostic = CatalogValues.diagnostic(diagnostic); }
        @Override public JsonObject diagnostic() { return diagnostic.deepCopy(); }
    }
    public enum NextKind { SEND, RUNNING, TERMINAL, UPLOAD_CANCELLED }
    public record Next(NextKind kind, Optional<Prepared> prepared, Optional<Outcome> outcome) {}
    public record Progress(Observation observation, Optional<Disposition> disposition, Optional<Outcome> outcome, Optional<Upload> upload) {}
    public record Capabilities(int version, String definition, int maxColumns, int maxRows, int maxSqlBytes, int maxIntentBytes, int maxActionBytes, int maxPreparedBytes, int residentIntents) {}
    public record Description(Configuration configuration, Policy policy, long resourceRevision) {}
    public sealed interface AssignmentValue permits Default, CellValue {}
    public enum Default implements AssignmentValue { VALUE }
    public record CellValue(Logical.Cell cell) implements AssignmentValue { public CellValue { Objects.requireNonNull(cell); } }
    public record Assignment(BigInteger column, AssignmentValue value) {
        public Assignment { positive(column); Objects.requireNonNull(value); }
        public Assignment(BigInteger column, Logical.Cell value) { this(column, new CellValue(value)); }
        JsonObject wire() { return obj("column", column.toString(), "value", value instanceof CellValue cell ? obj("cell", Logical.cellWire(cell.cell())) : obj("default", obj())); }
    }
    public sealed interface Predicate permits BooleanOperator, StatePredicate, Comparison { JsonObject wire(); }
    public enum BooleanOperator implements Predicate {
        ALL, NEGATE, CONJUNCTION, DISJUNCTION;
        public JsonObject wire() { return this == ALL ? obj("atom", obj("all", obj())) : obj(Logical.tag(this), obj()); }
    }
    public enum CellState { MISSING, NULL, TYPE_ERROR, VALUE, CONFLICT }
    public enum CompareOperator { EQ, NE, LT, LE, GT, GE }
    public record StatePredicate(BigInteger column, CellState state) implements Predicate {
        public StatePredicate { positive(column); Objects.requireNonNull(state); }
        public JsonObject wire() { return obj("atom", obj("state", obj("column", column.toString(), "value", Logical.tag(state)))); }
    }
    public record Comparison(BigInteger column, CompareOperator op, Logical.Atom value) implements Predicate {
        public Comparison { positive(column); Objects.requireNonNull(op); Objects.requireNonNull(value); }
        public JsonObject wire() { return obj("atom", obj("compare", obj("column", column.toString(), "op", Logical.tag(op), "value", Logical.atomWire(value)))); }
    }
    static Optional<List<Predicate>> predicates(Optional<List<Predicate>> values) { return values.map(list -> Logical.owned(list, 64)); }
    private static JsonElement predicateWire(Optional<List<Predicate>> values, WireBudget budget) { if (values.isEmpty()) return JsonNull.INSTANCE; JsonArray array = new JsonArray(); values.get().forEach(v -> array.add(budget.take(v.wire()))); return array; }
    private static JsonArray assignmentsWire(List<Assignment> values, WireBudget budget) { JsonArray result = new JsonArray(); values.forEach(v -> result.add(budget.take(v.wire()))); return result; }
    public sealed interface Mutation permits Insert, Update, Delete { Kind kind(); JsonObject wire(); }
    public record Insert(List<List<Assignment>> rows) implements Mutation {
        public Insert { rows = Logical.owned(rows, 1024).stream().map(row -> Logical.owned(row, 128)).toList(); if (rows.isEmpty()) throw new IllegalArgumentException("Empty INSERT"); }
        public Kind kind() { return Kind.INSERT; }
        public JsonObject wire() { WireBudget budget = new WireBudget(limit("catalog_action_bytes")); JsonArray values = new JsonArray(); rows.forEach(r -> values.add(assignmentsWire(r, budget))); return obj("action", obj("insert", values), "predicate", null); }
    }
    public record Update(List<Assignment> assignments, Optional<List<Predicate>> predicate) implements Mutation {
        public Update { assignments = Logical.owned(assignments, 128); predicate = predicates(predicate); }
        public Update(List<Assignment> assignments) { this(assignments, Optional.empty()); }
        public Kind kind() { return Kind.UPDATE; }
        public JsonObject wire() { WireBudget budget = new WireBudget(limit("catalog_action_bytes")); return obj("action", obj("update", assignmentsWire(assignments, budget)), "predicate", predicateWire(predicate, budget)); }
    }
    public record Delete(Optional<List<Predicate>> predicate) implements Mutation {
        public Delete { predicate = predicates(predicate); }
        public Delete() { this(Optional.empty()); }
        public Kind kind() { return Kind.DELETE; }
        public JsonObject wire() { return obj("action", obj("delete", obj()), "predicate", predicateWire(predicate, new WireBudget(limit("catalog_action_bytes")))); }
    }
    public sealed interface Change permits AddColumn, DropColumn, RenameColumn, SetDefault, SetNullable, SetType { JsonObject wire(); }
    public record AddColumn(String name, Logical.Descriptor type, boolean nullable, Optional<Logical.Cell> defaultValue, Optional<Long> maxCharacters) implements Change {
        public AddColumn { new Column(BigInteger.ONE, name, type, nullable, defaultValue, maxCharacters); }
        public AddColumn(String name, Logical.Descriptor type) { this(name, type, true, Optional.empty(), Optional.empty()); }
        public JsonObject wire() { return obj("add", columnWire(name, type, nullable, defaultValue, maxCharacters)); }
    }
    public record DropColumn(BigInteger column) implements Change { public DropColumn { positive(column); } public JsonObject wire() { return obj("drop", column.toString()); } }
    public record RenameColumn(BigInteger column, String name) implements Change { public RenameColumn { positive(column); Catalog.name(name); } public JsonObject wire() { return obj("rename", obj("column", column.toString(), "name", name)); } }
    public record SetDefault(BigInteger column, Optional<Logical.Cell> value) implements Change { public SetDefault { positive(column); Objects.requireNonNull(value); } public JsonObject wire() { return obj("default", obj("column", column.toString(), "value", value.map(Logical::cellWire).orElse(null))); } }
    public record SetNullable(BigInteger column, boolean nullable) implements Change { public SetNullable { positive(column); } public JsonObject wire() { return obj("nullable", obj("column", column.toString(), "value", nullable)); } }
    public record SetType(BigInteger column, Logical.Descriptor type, Optional<Long> maxCharacters) implements Change {
        public SetType { positive(column); Objects.requireNonNull(type); maxCharacters.ifPresent(Catalog::u32); }
        public JsonObject wire() { return obj("type", obj("column", column.toString(), "type", Logical.typeWire(type), "max_characters", maxCharacters.orElse(null))); }
    }
    public sealed interface Operation permits Create, Alter, Rename, Drop, Mutate { Kind kind(); BigInteger object(); JsonObject wire(); }
    public record Create(Schema schema, boolean ifNotExists) implements Operation {
        public Create { Objects.requireNonNull(schema); }
        public Create(Schema schema) { this(schema, false); }
        public Kind kind() { return Kind.CREATE; } public BigInteger object() { return schema.object(); }
        public JsonObject wire() { return obj("create", obj("schema", schema.wire(), "if_not_exists", ifNotExists)); }
    }
    public record Alter(Basis basis, Change change) implements Operation {
        public Alter { Objects.requireNonNull(basis); Objects.requireNonNull(change); }
        public Kind kind() { return Kind.ALTER; } public BigInteger object() { return basis.object(); }
        public JsonObject wire() { return obj("alter", obj("basis", basis.wire(), "change", change.wire())); }
    }
    public record Rename(Basis basis, String name) implements Operation {
        public Rename { Objects.requireNonNull(basis); Catalog.name(name); }
        public Kind kind() { return Kind.RENAME; } public BigInteger object() { return basis.object(); }
        public JsonObject wire() { return obj("rename", obj("basis", basis.wire(), "name", name)); }
    }
    public record Drop(Optional<Basis> basis, boolean ifExists) implements Operation {
        public Drop { Objects.requireNonNull(basis); }
        public Drop(Basis basis) { this(Optional.of(basis), false); }
        public Kind kind() { return Kind.DROP; } public BigInteger object() { return basis.map(Basis::object).orElse(BigInteger.ZERO); }
        public JsonObject wire() { return obj("drop", obj("basis", basis.map(Basis::wire).orElse(null), "if_exists", ifExists)); }
    }
    public record Mutate(Basis basis, Mutation mutation) implements Operation {
        public Mutate { Objects.requireNonNull(basis); Objects.requireNonNull(mutation); }
        public Kind kind() { return mutation.kind(); } public BigInteger object() { return basis.object(); }
        public JsonObject wire() { return obj("mutate", obj("basis", basis.wire(), "mutation", mutation.wire())); }
    }
    public record Dependency(Scope scope, BigInteger object, BigInteger identity, ProcessRef owner, DependencyKind kind) {
        public Dependency { new Connection(owner, scope); positive(object); positive(identity); Objects.requireNonNull(kind); }
        JsonObject wire(boolean present) { return obj("scope", scope.wire(), "object", object.toString(), "identity", identity.toString(), "owner", owner.pid(), "kind", Logical.tag(kind), "present", present); }
    }
    static Outcomes.AdmissionReceipt admission(JsonElement value) {
        try { return new Outcomes.AdmissionReceipt(number(Logical.fields(CatalogValues.result(value, "receipt"), "position").get("position"), 1)); }
        catch (RuntimeException | OutOfMemoryError error) { throw uncertain(); }
    }
    static Outcomes.AdmissionReceipt submission(Supplier<JsonObject> send) {
        JsonObject reply;
        try { reply = send.get(); } catch (TransitException error) { throw error; } catch (RuntimeException | OutOfMemoryError error) { throw uncertain(); }
        return admission(reply);
    }
    private static TransitException uncertain() { return new TransitException(TransitException.Kind.UNKNOWN_OUTCOME, 6, null, "catalog-submit"); }
    /** One owned port and intent. Cancelling a future does not cancel native work. */
    public static final class Client implements AutoCloseable {
        private final Connection connection;
        private final long principal;
        private final Worker<Bridge, Void> worker;
        private Client(ClientConfig config, Credential credential, Connection connection) {
            connection.wire(credential); this.connection = connection; this.principal = credential.principal();
            worker = new Worker<>(() -> {
                Bridge bridge = Bridge.catalog(config, credential, connection);
                try {
                    Capabilities caps = CatalogValues.decode(() -> CatalogValues.capabilities(CatalogValues.result(bridge.catalog(obj("capabilities", obj())), "capabilities")));
                    if (!CatalogValues.supported(caps)) throw new TransitException(TransitException.Kind.UNSUPPORTED_CAPABILITY, "catalog-capabilities");
                    return bridge;
                } catch (RuntimeException | Error error) { bridge.close(); throw error; }
            });
        }
        public static Client open(ClientConfig config, Credential credential, Connection connection) { return new Client(config, credential, connection); }
        public Connection connection() { return connection; }
        private <T> CompletableFuture<T> read(JsonObject action, String field, Function<JsonElement, T> decode) {
            text(action.toString(), limit("catalog_action_bytes"));
            return worker.submit(b -> { JsonObject response = b.catalog(action); return CatalogValues.decode(() -> decode.apply(CatalogValues.result(response, field))); });
        }
        public CompletableFuture<Capabilities> capabilities() { return read(obj("capabilities", obj()), "capabilities", CatalogValues::capabilities); }
        public CompletableFuture<Description> describe() { return read(obj("describe", obj()), "description", v -> CatalogValues.description(v, connection, principal)); }
        public CompletableFuture<Optional<Definition>> lookup(String name) { String requested = Catalog.name(name); return read(obj("lookup", requested), "definition", v -> CatalogValues.resolved(v, connection.scope(), requested)); }
        public CompletableFuture<Optional<HistoricalDefinition>> definition(BigInteger object, BigInteger revision) {
            return read(obj("definition", obj("object", positive(object).toString(), "revision", positive(revision).toString())), "historical", v -> CatalogValues.historical(v, connection.scope(), object, revision));
        }
        public CompletableFuture<Page> list() { return list(Optional.empty()); }
        public CompletableFuture<Page> list(Optional<Cursor> cursor) {
            if (cursor.isPresent() && !cursor.get().scope().equals(connection.scope())) throw new IllegalArgumentException("Foreign cursor");
            return read(obj("list", cursor.map(Cursor::wire).orElse(null)), "page", v -> CatalogValues.page(v, connection.scope(), cursor));
        }
        public CompletableFuture<Compiled> compileSql(String sql, Identity identity, Optional<BigInteger> createObject) {
            if (text(sql, 4096).isEmpty()) throw new IllegalArgumentException("Empty Table SQL");
            JsonObject action = obj("compile", obj("sql", sql, "identity", identity.wire(), "create_object", createObject.map(v -> positive(v).toString()).orElse(null)));
            return read(action, "compiled", v -> CatalogValues.compiled(v, connection, principal, identity, createObject.isPresent() ? Kind.CREATE : null, createObject.orElse(null)));
        }
        public CompletableFuture<Compiled> compileSql(String sql, Identity identity) { return compileSql(sql, identity, Optional.empty()); }
        public CompletableFuture<Compiled> prepare(String name, Identity identity, Operation operation) {
            JsonObject action = obj("prepare", obj("definition", DEFINITION, "identity", identity.wire(), "name", Catalog.name(name), "action", operation.wire()));
            return read(action, "compiled", v -> CatalogValues.compiled(v, connection, principal, identity, operation.kind(), operation.object()));
        }
        public CompletableFuture<Intent> load(SavedIntent saved) { return read(obj("load", saved.wire()), "loaded", v -> CatalogValues.intent(v, connection, principal)); }
        public CompletableFuture<Void> forget(Reference reference) { return read(obj("forget", reference.wire()), "forgotten", v -> { Logical.fields(v); return null; }); }
        public CompletableFuture<Next> next(Reference reference) { return read(obj("next", reference.wire()), "next", CatalogValues::next); }
        public CompletableFuture<State> status(Reference reference) { return read(obj("status", reference.wire()), "state", CatalogValues::state); }
        private CompletableFuture<Prepared> prepared(String name, JsonObject value) { return read(obj(name, value), "prepared", CatalogValues::prepared); }
        public CompletableFuture<Prepared> prepareResume(Reference reference) { return prepared("prepare_resume", reference.wire()); }
        public CompletableFuture<Prepared> prepareControl(Reference reference, Control control) { return prepared("prepare_control", obj("intent", reference.wire(), "control", Logical.tag(control))); }
        public CompletableFuture<Prepared> prepareInitialize(Configuration value) { return prepared("prepare_initialize", value.wire()); }
        public CompletableFuture<Prepared> preparePolicy(PolicyChange value) { return prepared("prepare_policy", value.wire()); }
        public CompletableFuture<Prepared> prepareDependency(Dependency value, boolean present) { return prepared("prepare_dependency", value.wire(present)); }
        public CompletableFuture<Outcomes.AdmissionReceipt> submit(Prepared prepared) { JsonObject action = obj("submit", prepared.wire()); return worker.submit(b -> submission(() -> b.catalog(action))); }
        private static JsonObject input(Prepared prepared, long position) { return obj("prepared", prepared.wire(), "input", counter(position, 1)); }
        public CompletableFuture<Observation> observe(Prepared prepared, long position, boolean wait) { return read(obj(wait ? "wait_observe" : "observe", input(prepared, position)), "observation", v -> Logical.variant(Observation.class, v)); }
        public CompletableFuture<Observation> observe(Prepared prepared, long position) { return observe(prepared, position, false); }
        public CompletableFuture<Optional<Disposition>> inputDisposition(Prepared prepared, long position) { return read(obj("input_disposition", input(prepared, position)), "disposition", CatalogValues::disposition); }
        public CompletableFuture<Progress> progress(Reference reference, Prepared prepared, long position, boolean wait) {
            JsonObject value = input(prepared, position); value.add("intent", reference.wire()); return read(obj(wait ? "wait_progress" : "progress", value), "progress", CatalogValues::progress);
        }
        public CompletableFuture<Progress> progress(Reference reference, Prepared prepared, long position) { return progress(reference, prepared, position, false); }
        @Override public void close() { worker.close(); }
    }
}
