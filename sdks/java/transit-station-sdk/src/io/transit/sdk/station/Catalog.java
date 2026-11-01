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
    public enum Encoding { PLAIN, BITPACKED, RLE, DICTIONARY, FSST, COMP, COMP_3, ZONED, IBM_HFP, EBCDIC }
    public enum Collation { NONE, UTF8_BINARY, ASCII_CI, EBCDIC_CP037, ICU_ROOT, EBCDIC_037_PAD, EBCDIC_1047_NOPAD }
    public enum Kind { CREATE, ALTER, RENAME, DROP, INSERT, UPDATE, DELETE }
    public enum Ingestion { POINT, BULK }
    public enum Dialect { TRANSIT, MYSQL }
    public enum WorkKind { TABLE, NAME_ASSERTION }
    public enum ObservationKind { DDL, ROWS, NAME_ASSERTION }
    public enum OperationState { NOT_OBSERVED, ADMITTED, REJECTED, CANCELLED, COMMITTED, UNCHANGED }
    public enum Phase { ADMITTED, READY, SETTLED, REJECTED, CANCELLED }
    public enum Reason { NONE, NAME_CONFLICT, OBJECT_CONFLICT, STALE_DEFINITION, STALE_DATA, DEPENDENCY, CONSTRAINT,
        DEFINITION_CHANGED, DATA_CHANGED, DUPLICATE_KEY, MISSING_ROW, INVALID_ROWS, WORK_LIMIT, CONDITION_CHANGED }
    public enum EvolutionWork { METADATA, VALIDATE_ROWS, REWRITE_ROWS }
    public record Scope(ResourceRef resource, BigInteger catalog) {
        public Scope { Objects.requireNonNull(resource); positive(catalog); }
        JsonObject wire() { return obj("realm", resource.realm(), "resource", resource.resource(), "catalog", catalog.toString()); }
    }
    public record Connection(Scope scope, long audience, BigInteger branch, Optional<Long> role) {
        public Connection(Scope scope, long audience) { this(scope, audience, BigInteger.ONE, Optional.empty()); }
        public Connection { Objects.requireNonNull(scope); counter(audience, 1); positive(branch); role.ifPresent(v -> counter(v, 0)); }
        JsonObject wire(long principal) { return obj("scope", scope.wire(), "audience", audience, "branch", branch.toString(), "role", role.orElse(null), "principal", counter(principal, 0)); }
        JsonObject wire(Credential identity) {
            if (identity.realm() != scope.resource().realm()) throw new IllegalArgumentException("Different credential realm");
            return wire(identity.principal());
        }
    }
    public record TableLimits(long recordBytes, BigInteger stagingBytes, long stagingRecords) {
        public TableLimits { u32(recordBytes); positive(stagingBytes); u32(stagingRecords); if (stagingBytes.compareTo(BigInteger.valueOf(recordBytes)) < 0) throw new IllegalArgumentException("Staging quota cannot hold a record"); }
        JsonObject wire() { return obj("record_bytes", recordBytes, "staging_bytes", stagingBytes.toString(), "staging_records", stagingRecords); }
    }
    /** Stable IDs allocated through explicit native provisioning. */
    public record AuthorityProfile(long databaseDomain, long schemaDomain, long tableDomain,
        long streamDomain, long queueDomain, long kvDomain, long database, long initialSchema, long initialSchemaAuthority) {
        public AuthorityProfile {
            for (long value : new long[]{databaseDomain, schemaDomain, tableDomain, streamDomain, queueDomain, kvDomain, database, initialSchema, initialSchemaAuthority}) counter(value, 1);
            long[] domains = {databaseDomain, schemaDomain, tableDomain, streamDomain, queueDomain, kvDomain};
            for (int i = 0; i < domains.length; i++) for (int j = 0; j < i; j++)
                if (domains[i] == domains[j]) throw new IllegalArgumentException("Distinct native authorization domains are required");
            if (database == initialSchemaAuthority)
                throw new IllegalArgumentException("Distinct native authorization bindings are required");
        }
        JsonObject wire() { return obj("database_domain", databaseDomain, "schema_domain", schemaDomain, "table_domain", tableDomain, "stream_domain", streamDomain, "queue_domain", queueDomain, "kv_domain", kvDomain,
            "database", database, "initial_schema", initialSchema, "initial_schema_authority", initialSchemaAuthority); }
    }
    /** An observed authenticated subject; the observation grants no authority. */
    public record Subject(long principal, long loginRole, long role, long credentialEpoch, long audience, Bytes context) {
        public Subject { counter(principal, 0); counter(loginRole, 0); counter(role, 0); counter(credentialEpoch, 1); counter(audience, 1); digest(context); }
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
    public record Column(BigInteger id, String name, Logical.Descriptor type, boolean nullable, Optional<Logical.Cell> defaultValue, Optional<Long> maxCharacters, Encoding encoding, Collation collation) {
        public Column { Objects.requireNonNull(encoding); Objects.requireNonNull(collation); positive(id); Catalog.name(name); Objects.requireNonNull(type); Objects.requireNonNull(defaultValue); maxCharacters.ifPresent(Catalog::u32); }
        public Column(BigInteger id, String name, Logical.Descriptor type) { this(id, name, type, true, Optional.empty(), Optional.empty(), Encoding.PLAIN, Collation.NONE); }
        JsonObject wire() { JsonObject out = columnWire(name, type, nullable, defaultValue, maxCharacters, encoding, collation); out.addProperty("id", id.toString()); return out; }
    }
    static JsonObject columnWire(String name, Logical.Descriptor type, boolean nullable, Optional<Logical.Cell> defaultValue, Optional<Long> maxCharacters, Encoding encoding, Collation collation) {
        return obj("name", name, "type", Logical.typeWire(type), "nullable", nullable, "default", defaultValue.map(Logical::cellWire).orElse(null), "max_characters", maxCharacters.orElse(null), "encoding", Logical.tag(encoding), "collation", Logical.tag(collation));
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
    public record Identity(BigInteger operation, long namespace) {
        public Identity { positive(operation); counter(namespace, 1); }
        public Identity(BigInteger operation) { this(operation, 1); }
    }
    public record Counts(BigInteger matched, BigInteger changed) {
        public Counts { u64(matched); u64(changed); if (changed.compareTo(matched) > 0) throw new IllegalArgumentException("Changed exceeds matched"); }
    }
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
    public sealed interface Change permits AddColumn, DropColumn, RenameColumn, SetDefault, SetNullable, SetType, SetPhysical { JsonObject wire(); }
    public record AddColumn(String name, Logical.Descriptor type, boolean nullable, Optional<Logical.Cell> defaultValue, Optional<Long> maxCharacters, Encoding encoding, Collation collation) implements Change {
        public AddColumn { new Column(BigInteger.ONE, name, type, nullable, defaultValue, maxCharacters, encoding, collation); }
        public AddColumn(String name, Logical.Descriptor type) { this(name, type, true, Optional.empty(), Optional.empty(), Encoding.PLAIN, Collation.NONE); }
        public JsonObject wire() { return obj("add", columnWire(name, type, nullable, defaultValue, maxCharacters, encoding, collation)); }
    }
    public record DropColumn(BigInteger column) implements Change { public DropColumn { positive(column); } public JsonObject wire() { return obj("drop", column.toString()); } }
    public record RenameColumn(BigInteger column, String name) implements Change { public RenameColumn { positive(column); Catalog.name(name); } public JsonObject wire() { return obj("rename", obj("column", column.toString(), "name", name)); } }
    public record SetDefault(BigInteger column, Optional<Logical.Cell> value) implements Change { public SetDefault { positive(column); Objects.requireNonNull(value); } public JsonObject wire() { return obj("default", obj("column", column.toString(), "value", value.map(Logical::cellWire).orElse(null))); } }
    public record SetNullable(BigInteger column, boolean nullable) implements Change { public SetNullable { positive(column); } public JsonObject wire() { return obj("nullable", obj("column", column.toString(), "value", nullable)); } }
    public record SetType(BigInteger column, Logical.Descriptor type, Optional<Long> maxCharacters) implements Change {
        public SetType { positive(column); Objects.requireNonNull(type); maxCharacters.ifPresent(Catalog::u32); }
        public JsonObject wire() { return obj("type", obj("column", column.toString(), "type", Logical.typeWire(type), "max_characters", maxCharacters.orElse(null))); }
    }
    public record SetPhysical(BigInteger column, Encoding encoding, Collation collation) implements Change {
        public SetPhysical { positive(column); Objects.requireNonNull(encoding); Objects.requireNonNull(collation); }
        public JsonObject wire() { return obj("physical", obj("column", column.toString(), "encoding", Logical.tag(encoding), "collation", Logical.tag(collation))); }
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
    public record Mutate(Basis basis, Mutation mutation, Ingestion ingestion) implements Operation {
        public Mutate { Objects.requireNonNull(basis); Objects.requireNonNull(mutation); Objects.requireNonNull(ingestion); }
        public Mutate(Basis basis, Mutation mutation) { this(basis, mutation, Ingestion.POINT); }
        public Kind kind() { return mutation.kind(); } public BigInteger object() { return basis.object(); }
        public JsonObject wire() { return obj("mutate", obj("basis", basis.wire(), "mutation", mutation.wire(), "ingestion", Logical.tag(ingestion))); }
    }
    public record Position(BigInteger partition, BigInteger nextLsn) {
        public Position { positive(partition); u64(nextLsn); }
        JsonObject wire() { return obj("partition", partition.toString(), "next_lsn", nextLsn.toString()); }
    }
    public record ObjectIdentity(Scope scope, BigInteger branch, BigInteger object) {
        public ObjectIdentity { Objects.requireNonNull(scope); positive(branch); positive(object); }
        JsonObject wire() { return obj("scope", scope.wire(), "branch", branch.toString(), "object", object.toString()); }
    }
    public record Interpretation(ObjectIdentity object, BigInteger revision, Bytes digest) {
        public Interpretation { Objects.requireNonNull(object); positive(revision); Catalog.digest(digest); }
    }
    public record Content(BigInteger bytes, Bytes sha256) { public Content { positive(bytes); digest(sha256); } }
    public record StoredDefinition(Interpretation interpretation, Content content, Bytes schemaFingerprint, boolean retired) {
        public StoredDefinition { digest(schemaFingerprint); if (!interpretation.digest().equals(content.sha256())) throw new IllegalArgumentException("Changed definition content"); }
    }
    public record Configuration(Scope scope, BigInteger branch, BigInteger partition, long audience, AuthorityProfile authority, String databaseName, String initialSchemaName) {}
    public record Description(Configuration configuration, Subject subject, long policyRevision) {}
    public record Capabilities(int version, String definition, int maxColumns, int maxRows, int maxSqlBytes, int maxIntentBytes, int maxActionBytes, int metadataPageEntries, int residentIntents) {}
    public record Metadata(Basis basis, long authorization, Position position, BigInteger changedLsn, BigInteger rowCount, Schema schema) {}
    public record Namespace(Scope scope, long id, long authorization, String name, long revision, boolean retired) {}
    public record Entry(Interpretation interpretation, long namespace, String name, Position position, BigInteger changedLsn) {}
    public enum Consistency { INDEPENDENT }
    public record Page<T>(Position position, List<T> entries, Optional<Cursor> next, Optional<Consistency> consistency) {
        public Page { entries = List.copyOf(entries); }
    }
    public record Commit(StoredDefinition definition, Position position, BigInteger matched, BigInteger affected, BigInteger liveRows) {}
    public record Observation(ObservationKind kind, OperationState state, Reference reference, Optional<Commit> commit, Optional<Phase> phase, Optional<Reason> reason, Optional<Position> position) {}
    public sealed interface PreviewCurrent permits CurrentBasis, CurrentName {}
    public record CurrentBasis(StoredDefinition definition, Position position, BigInteger changedLsn, BigInteger rowCount) implements PreviewCurrent {}
    public record CurrentName(Interpretation interpretation) implements PreviewCurrent {}
    public record Preview(ObservationKind kind, Intent intent, Position position, Optional<PreviewCurrent> current,
        Optional<Reason> reason, Optional<EvolutionWork> work, Optional<Boolean> rebuildKey, Optional<Bytes> schemaFingerprint, Optional<Boolean> matches) {}
    public record ReadAuthority(long database, long schema, long table) {
        public ReadAuthority { counter(database, 1); counter(schema, 1); counter(table, 1); if (database == schema || database == table || schema == table) throw new IllegalArgumentException("Conflicting authority identities"); }
    }
    public record SnapshotStatus(SnapshotOwner owner, Interpretation currentInterpretation, Position currentPosition, boolean retired, Optional<Snapshot> snapshot, boolean released, ReadAuthority authority) {}
    public record SnapshotMetadata(Snapshot snapshot, StoredDefinition interpretation, Position accepted, BigInteger changedLsn, BigInteger rowCount, Schema schema, ReadAuthority authority) {}
    public record Compiled(Intent intent, SavedIntent saved) {}
    public static final class Intent {
        private final String id, binding;
        private final WorkKind kind;
        private final Identity identity;
        private final SavedIntent saved;
        Intent(JsonObject id, JsonObject binding, WorkKind kind, Identity identity, SavedIntent saved) {
            this.id = id.toString(); this.binding = binding.toString(); this.kind = kind; this.identity = identity; this.saved = saved;
        }
        JsonObject id() { return CatalogValues.parseSaved(id); }
        JsonObject binding() { return CatalogValues.parseSaved(binding); }
        public WorkKind kind() { return kind; }
        public Identity identity() { return identity; }
        public SavedIntent saved() { return saved; }
        @Override public String toString() { return "Intent[owned local work]"; }
    }
    /** Preserve this exact value when a mutating result is uncertain. */
    public sealed interface Recovery permits SavedIntent, Reference, SnapshotAcquisition, Snapshot { String save(); }
    private abstract static class Saved {
        private final String data;
        Saved(JsonObject value) { data = value.toString(); }
        public final String save() { return data; }
        final JsonObject wire() { return CatalogValues.parseSaved(data); }
        @Override public final boolean equals(Object other) { return other != null && other.getClass() == getClass() && wire().equals(((Saved) other).wire()); }
        @Override public final int hashCode() { return wire().hashCode(); }
        @Override public final String toString() { return getClass().getSimpleName() + "[owned saved binding]"; }
    }
    public static final class Basis extends Saved {
        private Basis(JsonObject value) { super(value); }
        public static Basis restore(String data) {
            JsonObject value = CatalogValues.parseSaved(data);
            CatalogValues.action(obj("prepare", obj("definition", DEFINITION, "namespace", 1, "operation", "1", "name", "check", "action", obj("drop", obj("basis", value, "if_exists", false)))));
            definition(string(value.get("definition"))); counter(number(value.get("namespace"), 1), 1); Catalog.name(string(value.get("name")));
            Connection c = CatalogValues.connection(value.get("connection")); StoredDefinition stored = CatalogValues.stored(value.get("interpretation"));
            CatalogValues.owns(c, stored.interpretation().object());
            if (stored.retired()) throw new IllegalArgumentException("Cannot prepare from retired definition");
            return new Basis(value);
        }
        public Connection connection() { return CatalogValues.connection(wire().get("connection")); }
        public long principal() { return number(wire().getAsJsonObject("connection").get("principal"), 0); }
        public long namespace() { return number(wire().get("namespace"), 1); }
        public String name() { return string(wire().get("name")); }
        public StoredDefinition interpretation() { return CatalogValues.stored(wire().get("interpretation")); }
        public BigInteger object() { return interpretation().interpretation().object().object(); }
    }
    public static final class SavedIntent extends Saved implements Recovery {
        private SavedIntent(JsonObject value) { super(value); }
        public static SavedIntent restore(String data) {
            JsonObject value = CatalogValues.parseSaved(data); CatalogValues.action(obj("load", value));
            if (value.has("table")) {
                JsonObject table = value.getAsJsonObject("table"); definition(string(table.get("definition"))); number(table.get("namespace"), 1);
                if (unhex(table.get("bytes"), limit("catalog_intent_bytes")).length == 0) throw new IllegalArgumentException("Empty saved intent");
            } else CatalogValues.assertion(value.getAsJsonObject("name_assertion"));
            return new SavedIntent(value);
        }
    }
    public static final class Reference extends Saved implements Recovery {
        private Reference(JsonObject value) { super(value); }
        public static Reference restore(String data) {
            JsonObject value = CatalogValues.parseSaved(data); CatalogValues.action(obj("admit", value));
            if (value.has("table")) {
                JsonObject table = value.getAsJsonObject("table"); definition(string(table.get("definition"))); number(table.get("namespace"), 1);
                JsonObject c = table.getAsJsonObject("connection"); CatalogValues.checkBinding(table.getAsJsonObject("binding"), CatalogValues.connection(c), number(c.get("principal"), 0));
                Content content = CatalogValues.content(table.get("content"));
                if (content.bytes().compareTo(BigInteger.valueOf(36)) <= 0 || content.bytes().compareTo(BigInteger.valueOf(limit("catalog_intent_bytes"))) > 0) throw new IllegalArgumentException("Invalid saved work length");
            } else CatalogValues.assertion(value.getAsJsonObject("name_assertion"));
            return new Reference(value);
        }
        public WorkKind kind() { return wire().has("table") ? WorkKind.TABLE : WorkKind.NAME_ASSERTION; }
        JsonObject value() { return wire().getAsJsonObject(Logical.tag(kind())); }
        JsonObject binding() { return kind() == WorkKind.TABLE ? value().getAsJsonObject("binding") : value(); }
        public Connection connection() { return CatalogValues.connection(value().get("connection")); }
        public long principal() { return number(value().getAsJsonObject("connection").get("principal"), 0); }
        public Identity identity() { return new Identity(CatalogValues.wide(kind() == WorkKind.TABLE ? binding().getAsJsonObject("identity").get("operation") : value().get("operation")), number(value().get("namespace"), 1)); }
    }
    public static final class Cursor extends Saved {
        private Cursor(JsonObject value) { super(value); }
        public static Cursor restore(String data) {
            JsonObject value = CatalogValues.parseSaved(data), selection = value.getAsJsonObject("selection");
            CatalogValues.action(obj("catalog", selection.has("namespaces") ? obj("namespaces", value) : obj("tables", obj("namespace", selection.get("tables"), "cursor", value))));
            definition(string(value.get("definition"))); CatalogValues.connection(value.get("connection"));
            Position position = CatalogValues.position(value.get("position")); BigInteger after = CatalogValues.wide(value.get("after"));
            if (position.nextLsn().signum() == 0) throw new IllegalArgumentException("Invalid directory position");
            if (selection.has("namespaces")) counter(after.longValueExact(), 1);
            return new Cursor(value);
        }
        void check(Connection c, long principal, JsonObject selection) {
            if (!wire().get("connection").equals(c.wire(principal)) || !wire().get("selection").equals(selection)) throw new IllegalArgumentException("Foreign cursor");
        }
        public Position position() { return CatalogValues.position(wire().get("position")); }
        public BigInteger after() { return CatalogValues.wide(wire().get("after")); }
    }
    public static final class SnapshotOwner extends Saved {
        private SnapshotOwner(JsonObject value) { super(value); }
        public static SnapshotOwner restore(String data) {
            JsonObject value = CatalogValues.parseSaved(data); CatalogValues.action(obj("retention", obj("status", value)));
            definition(string(value.get("definition"))); CatalogValues.wide(value.get("operation"));
            CatalogValues.owns(CatalogValues.connection(value.get("connection")), CatalogValues.objectIdentity(value.get("object")));
            return new SnapshotOwner(value);
        }
        public Connection connection() { return CatalogValues.connection(wire().get("connection")); }
        public long principal() { return number(wire().getAsJsonObject("connection").get("principal"), 0); }
        public ObjectIdentity object() { return CatalogValues.objectIdentity(wire().get("object")); }
        public BigInteger operation() { return CatalogValues.wide(wire().get("operation")); }
    }
    public static final class SnapshotAcquisition extends Saved implements Recovery {
        private SnapshotAcquisition(JsonObject value) { super(value); }
        public static SnapshotAcquisition restore(String data) {
            JsonObject value = CatalogValues.parseSaved(data); CatalogValues.action(obj("retention", obj("acquire", value)));
            SnapshotOwner.restore(value.get("owner").toString()); CatalogValues.position(value.get("expected")); return new SnapshotAcquisition(value);
        }
        public SnapshotOwner owner() { return SnapshotOwner.restore(wire().get("owner").toString()); }
        public Position expected() { return CatalogValues.position(wire().get("expected")); }
    }
    public static final class Snapshot extends Saved implements Recovery {
        private Snapshot(JsonObject value) { super(value); }
        public static Snapshot restore(String data) {
            JsonObject value = CatalogValues.parseSaved(data); CatalogValues.action(obj("retention", obj("metadata", value)));
            SnapshotOwner.restore(value.get("owner").toString()); CatalogValues.content(value.get("content")); return new Snapshot(value);
        }
        public SnapshotOwner owner() { return SnapshotOwner.restore(wire().get("owner").toString()); }
        public Content content() { return CatalogValues.content(wire().get("content")); }
    }
    public static final class Uncertain extends RuntimeException {
        private static final long serialVersionUID = 1L;
        @SuppressWarnings("serial") // Recovery is saved explicitly; Java serialization is refused.
        private final Recovery original;
        private final TransitException failure;
        Uncertain(Recovery original, Throwable cause) {
            super("Catalog outcome is uncertain; retain the original saved binding", cause);
            this.original = Objects.requireNonNull(original);
            failure = cause instanceof TransitException error && error.kind() == TransitException.Kind.UNKNOWN_OUTCOME ? error :
                new TransitException(TransitException.Kind.UNKNOWN_OUTCOME, 6, null, "catalog");
        }
        @java.io.Serial private void writeObject(java.io.ObjectOutputStream out) throws java.io.IOException {
            throw new java.io.NotSerializableException("Save the original catalog recovery value explicitly");
        }
        @java.io.Serial private void readObject(java.io.ObjectInputStream in) throws java.io.IOException {
            throw new java.io.InvalidObjectException("Restore the saved catalog recovery value explicitly");
        }
        public Recovery original() { return original; }
        public TransitException failure() { return failure; }
    }
    /** One owned port and intent. Future cancellation does not cancel native work. */
    public static final class Client implements AutoCloseable {
        private final Connection connection;
        private final long principal;
        private final Worker<Bridge, Void> worker;
        private Client(ClientConfig config, Credential credential, Connection connection, String serviceUrl) {
            if (serviceUrl != null) { text(serviceUrl, 2048); new ClientConfig(java.net.URI.create(serviceUrl), ClientConfig.Profile.NATIVE_V1); }
            connection.wire(credential); this.connection = connection; principal = credential.principal();
            worker = new Worker<>(() -> {
                Bridge bridge = Bridge.catalog(config, credential, connection, serviceUrl);
                try {
                    JsonObject result = bridge.catalog(obj("catalog", obj("capabilities", obj())));
                    CatalogValues.response(result);
                    CatalogValues.capabilities(CatalogValues.path(result, "catalog", "capabilities"));
                    return bridge;
                } catch (RuntimeException | Error error) { bridge.close(); throw error; }
            });
        }
        public static Client open(ClientConfig config, Credential credential, Connection connection) { return new Client(config, credential, connection, null); }
        public static Client open(ClientConfig config, Credential credential, Connection connection, String serviceUrl) { return new Client(config, credential, connection, serviceUrl); }
        public Connection connection() { return connection; }
        private <T> CompletableFuture<T> read(JsonObject action, Recovery original, Function<JsonElement,T> decode, String... path) {
            CatalogValues.action(action); String data = text(action.toString(), limit("catalog_action_bytes"));
            return worker.submit(bridge -> {
                JsonObject response;
                try { response = bridge.catalog(CatalogValues.parseSaved(data)); }
                catch (TransitException error) { if (original != null && error.kind() == TransitException.Kind.UNKNOWN_OUTCOME) throw new Uncertain(original, error); throw error; }
                catch (OutOfMemoryError error) { if (original != null) throw new Uncertain(original, error); throw error; }
                try {
                    return CatalogValues.decode(() -> { CatalogValues.response(response); return decode.apply(CatalogValues.path(response, path)); });
                } catch (RuntimeException | OutOfMemoryError error) { if (original != null) throw new Uncertain(original, error); throw error; }
            });
        }
        private void owner(Connection c, long p) { if (!connection.equals(c) || p != principal) throw new IllegalArgumentException("Foreign catalog caller"); }
        public CompletableFuture<Capabilities> capabilities() { return read(obj("catalog", obj("capabilities", obj())), null, CatalogValues::capabilities, "catalog", "capabilities"); }
        public CompletableFuture<Description> describe() { return read(obj("catalog", obj("describe", obj())), null, v -> CatalogValues.description(v, connection, principal), "catalog", "description"); }
        public CompletableFuture<Optional<Namespace>> namespace(long id) {
            counter(id, 1); return read(obj("catalog", obj("namespace", id)), null, v -> CatalogValues.optional(v, value -> {
                Namespace found = CatalogValues.namespace(value); if (found.id() != id || !found.scope().equals(connection.scope())) throw incompatible("catalog-namespace"); return found;
            }), "catalog", "namespace");
        }
        public CompletableFuture<Page<Namespace>> namespaces(Optional<Cursor> cursor) {
            JsonObject selection = obj("namespaces", obj()); cursor.ifPresent(v -> v.check(connection, principal, selection));
            return read(obj("catalog", obj("namespaces", cursor.map(Cursor::wire).orElse(null))), null,
                v -> CatalogValues.namespaces(v, connection, principal, cursor), "catalog", "namespaces");
        }
        public CompletableFuture<Page<Namespace>> namespaces() { return namespaces(Optional.empty()); }
        public CompletableFuture<Page<Entry>> tables(long namespace, Optional<Cursor> cursor) {
            counter(namespace, 1); JsonObject selection = obj("tables", namespace); cursor.ifPresent(v -> v.check(connection, principal, selection));
            return read(obj("catalog", obj("tables", obj("namespace", namespace, "cursor", cursor.map(Cursor::wire).orElse(null)))), null,
                v -> CatalogValues.tables(v, connection, principal, namespace, cursor), "catalog", "tables");
        }
        public CompletableFuture<Page<Entry>> tables() { return tables(1, Optional.empty()); }
        public CompletableFuture<Optional<Metadata>> lookup(String name, long namespace) {
            Catalog.name(name); counter(namespace, 1);
            return read(obj("lookup", obj("namespace", namespace, "name", name)), null,
                v -> CatalogValues.optional(v, raw -> CatalogValues.metadata(raw, connection, principal, namespace, name)), "metadata");
        }
        public CompletableFuture<Optional<Metadata>> lookup(String name) { return lookup(name, 1); }
        private CompletableFuture<Compiled> compiled(JsonObject action, Identity identity) {
            return read(action, null, value -> {
                JsonObject v = object(value); SavedIntent saved = SavedIntent.restore(v.get("saved").toString());
                return new Compiled(CatalogValues.summary(v.get("summary"), saved, connection, principal, identity), saved);
            }, "compiled");
        }
        public CompletableFuture<Compiled> compileSql(String sql, Identity identity, Optional<BigInteger> createObject, Dialect dialect, Ingestion ingestion) {
            if (text(sql, 4096).isEmpty()) throw new IllegalArgumentException("Empty SQL");
            return compiled(obj("compile", obj("sql", sql, "namespace", identity.namespace(), "operation", identity.operation().toString(),
                "create_object", createObject.map(v -> positive(v).toString()).orElse(null), "dialect", Logical.tag(dialect), "ingestion", Logical.tag(ingestion))), identity);
        }
        public CompletableFuture<Compiled> compileSql(String sql, Identity identity, Optional<BigInteger> createObject) { return compileSql(sql, identity, createObject, Dialect.TRANSIT, Ingestion.POINT); }
        public CompletableFuture<Compiled> compileSql(String sql, Identity identity) { return compileSql(sql, identity, Optional.empty()); }
        public CompletableFuture<Compiled> prepare(String name, Identity identity, Operation operation) {
            return compiled(obj("prepare", obj("definition", DEFINITION, "namespace", identity.namespace(), "operation", identity.operation().toString(), "name", Catalog.name(name), "action", operation.wire())), identity);
        }
        public CompletableFuture<Intent> load(SavedIntent saved) { return read(obj("load", saved.wire()), null, v -> CatalogValues.summary(v, saved, connection, principal, null), "loaded"); }
        public CompletableFuture<Void> forget(Intent intent) { return read(obj("forget", intent.id()), null, v -> null, "forgotten"); }
        public CompletableFuture<Preview> preview(Intent intent) { return read(obj("preview", intent.id()), null, v -> CatalogValues.preview(v, intent), "preview"); }
        public CompletableFuture<Reference> stage(Intent intent) {
            return read(obj("stage", intent.id()), intent.saved(), v -> {
                Reference reference = Reference.restore(v.toString()); owner(reference.connection(), reference.principal());
                if (reference.kind() != intent.kind() || !reference.binding().equals(intent.binding()) || reference.identity().namespace() != intent.identity().namespace()) throw incompatible("catalog-staged-binding");
                return reference;
            }, "staged");
        }
        public CompletableFuture<Observation> admit(Reference original) {
            owner(original.connection(), original.principal());
            return read(obj("admit", original.wire()), original, v -> CatalogValues.observation(v, original), "observation");
        }
        private CompletableFuture<Observation> operation(Reference original, String command, int steps) {
            owner(original.connection(), original.principal()); if (steps < 1 || steps > 65535) throw new IllegalArgumentException("Invalid execution budget");
            return read(obj("operation", obj("reference", original.wire(), "command", command, "steps", steps)), command.equals("inspect") ? null : original,
                v -> CatalogValues.observation(v, original), "observation");
        }
        public CompletableFuture<Observation> inspect(Reference original) { return operation(original, "inspect", 1); }
        public CompletableFuture<Observation> execute(Reference original, int steps) { return operation(original, "execute", steps); }
        public CompletableFuture<Observation> cancel(Reference original) { return operation(original, "cancel", 1); }
        public SnapshotAcquisition prepareSnapshot(Metadata metadata, BigInteger operation) {
            Basis basis = metadata.basis(); owner(basis.connection(), basis.principal());
            return SnapshotAcquisition.restore(obj("owner", obj("definition", DEFINITION, "connection", connection.wire(principal),
                "object", basis.interpretation().interpretation().object().wire(), "operation", positive(operation).toString()), "expected", metadata.position().wire()).toString());
        }
        public CompletableFuture<Snapshot> acquireSnapshot(SnapshotAcquisition acquisition) {
            SnapshotOwner owner = acquisition.owner(); owner(owner.connection(), owner.principal());
            return read(obj("retention", obj("acquire", acquisition.wire())), acquisition, v -> {
                Snapshot snapshot = Snapshot.restore(v.toString()); if (!snapshot.owner().equals(owner)) throw incompatible("catalog-snapshot-owner"); return snapshot;
            }, "retention", "acquired");
        }
        public CompletableFuture<SnapshotStatus> snapshotStatus(SnapshotOwner owner) {
            owner(owner.connection(), owner.principal());
            return read(obj("retention", obj("status", owner.wire())), null, v -> CatalogValues.snapshotStatus(v, owner), "retention", "status");
        }
        public CompletableFuture<SnapshotMetadata> snapshotMetadata(Snapshot snapshot) {
            owner(snapshot.owner().connection(), snapshot.owner().principal());
            return read(obj("retention", obj("metadata", snapshot.wire())), null, v -> CatalogValues.snapshotMetadata(v, snapshot), "retention", "metadata");
        }
        public CompletableFuture<Snapshot> releaseSnapshot(Snapshot snapshot) {
            owner(snapshot.owner().connection(), snapshot.owner().principal());
            return read(obj("retention", obj("release", snapshot.wire())), snapshot, v -> {
                if (!v.equals(snapshot.wire())) throw incompatible("catalog-released-snapshot"); return snapshot;
            }, "retention", "released");
        }
        @Override public void close() { worker.close(); }
    }
}
