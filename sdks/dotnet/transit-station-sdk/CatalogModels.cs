using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk.Internal;
using V = Transit.Client.Internal.Value;

namespace Transit.Station.Sdk;

public static partial class Catalog
{
    public static string ContractDefinition => NativeApi.Definition;
    internal static readonly JsonObject Contract = V.ReadContract(typeof(Catalog).Assembly, "transit.station.contract.json");
    internal static int Limit(string name) => checked((int)V.Number(V.Object(Contract["limits"])[name], 1));
    internal static ulong Positive(ulong value) => value == 0 ? throw new ArgumentException("Expected positive Table identity") : value;
    internal static uint Positive(uint value) => value == 0 ? throw new ArgumentException("Expected positive Table bound") : value;
    internal static string Identifier(string value) { V.Text(value, 255); if (value.Length == 0 || value.Contains('\0')) throw new ArgumentException("Invalid Table name"); return value; }
    internal static string Current(string value) => value == ContractDefinition ? value : throw new ArgumentException("Missing or foreign Table definition");
    internal static Bytes Digest(Bytes value) { ArgumentNullException.ThrowIfNull(value); if (value.Length != 32) throw new ArgumentException("Expected digest"); return value; }
    public enum Encoding { Plain, Bitpacked, Rle, Dictionary, Fsst, Comp, Comp_3, Zoned, IbmHfp, Ebcdic }
    public enum Collation { None, Utf8Binary, AsciiCi, EbcdicCp037, IcuRoot }
    public enum Kind { Create, Alter, Rename, Drop, Insert, Update, Delete }
    public enum Ingestion { Point, Bulk }
    public enum Dialect { Transit, Mysql }
    public enum WorkKind { Table, NameAssertion }
    public enum ObservationKind { Ddl, Rows, NameAssertion }
    public enum OperationState { NotObserved, Admitted, Rejected, Cancelled, Committed, Unchanged }
    public enum Phase { Admitted, Ready, Settled, Rejected, Cancelled }
    public enum Reason { None, NameConflict, ObjectConflict, StaleDefinition, StaleData, Dependency, Constraint, DefinitionChanged, DataChanged, DuplicateKey, MissingRow, InvalidRows, WorkLimit, ConditionChanged }
    public enum EvolutionWork { Metadata, ValidateRows, RewriteRows }
    public sealed record Scope {
        public ResourceRef Resource { get; }
        public ulong CatalogId { get; }
        public Scope(ResourceRef resource, ulong catalogId) { ArgumentNullException.ThrowIfNull(resource); Resource = resource; CatalogId = Positive(catalogId); }
        internal JsonObject Wire() => V.Obj(("realm", Resource.Realm), ("resource", Resource.Resource), ("catalog", Turn.Decimal(CatalogId)));
    }
    public sealed record Connection {
        public Scope Scope { get; }
        public ulong Audience { get; }
        public ulong Branch { get; }
        public ulong? Role { get; }
        public Connection(Scope scope, ulong audience, ulong branch = 1, ulong? role = null) {
            ArgumentNullException.ThrowIfNull(scope); Scope = scope; Audience = V.Counter(audience); Branch = Positive(branch); Role = role.HasValue ? V.Counter(role.Value, 0) : null;
        }
        internal JsonObject Wire(ulong principal) => V.Obj(("scope", Scope.Wire()), ("audience", Audience), ("branch", Turn.Decimal(Branch)), ("role", Role), ("principal", V.Counter(principal, 0)));
        internal JsonObject Wire(Credential identity) {
            if (identity.Realm != Scope.Resource.Realm) throw new ArgumentException("Different credential realm"); return Wire(identity.Principal);
        }
    }
    public sealed record TableLimits {
        public uint RecordBytes { get; }
        public ulong StagingBytes { get; }
        public uint StagingRecords { get; }
        public TableLimits(uint recordBytes, ulong stagingBytes, uint stagingRecords) { RecordBytes = Positive(recordBytes); StagingBytes = Positive(stagingBytes); StagingRecords = Positive(stagingRecords); if (stagingBytes < recordBytes) throw new ArgumentException("Staging quota cannot hold one record"); }
        internal JsonObject Wire() => V.Obj(("record_bytes", (ulong)RecordBytes), ("staging_bytes", Turn.Decimal(StagingBytes)), ("staging_records", (ulong)StagingRecords));
    }
    /// <summary>Stable bindings allocated by explicit native provisioning.</summary>
    public sealed record AuthorityProfile {
        public ulong DatabaseDomain { get; }
        public ulong SchemaDomain { get; }
        public ulong TableDomain { get; }
        public ulong StreamDomain { get; }
        public ulong QueueDomain { get; }
        public ulong KvDomain { get; }
        public ulong Database { get; }
        public ulong InitialSchema { get; }
        public ulong InitialSchemaAuthority { get; }
        public AuthorityProfile(ulong databaseDomain, ulong schemaDomain, ulong tableDomain, ulong streamDomain, ulong queueDomain, ulong kvDomain, ulong database, ulong initialSchema, ulong initialSchemaAuthority) {
            DatabaseDomain = V.Counter(databaseDomain); SchemaDomain = V.Counter(schemaDomain); TableDomain = V.Counter(tableDomain);
            StreamDomain = V.Counter(streamDomain); QueueDomain = V.Counter(queueDomain); KvDomain = V.Counter(kvDomain);
            Database = V.Counter(database); InitialSchema = V.Counter(initialSchema); InitialSchemaAuthority = V.Counter(initialSchemaAuthority);
            if (new[] { databaseDomain, schemaDomain, tableDomain, streamDomain, queueDomain, kvDomain }.Distinct().Count() != 6 || database == initialSchemaAuthority)
                throw new ArgumentException("Distinct native authorization bindings are required");
        }
        internal JsonObject Wire() => V.Obj(("database_domain", DatabaseDomain), ("schema_domain", SchemaDomain), ("table_domain", TableDomain), ("stream_domain", StreamDomain), ("queue_domain", QueueDomain), ("kv_domain", KvDomain),
            ("database", Database), ("initial_schema", InitialSchema), ("initial_schema_authority", InitialSchemaAuthority));
    }
    /// <summary>An observed authenticated subject; it grants no authority.</summary>
    public sealed record Subject {
        public ulong Principal { get; }
        public ulong LoginRole { get; }
        public ulong Role { get; }
        public ulong CredentialEpoch { get; }
        public ulong Audience { get; }
        public Bytes Context { get; }
        public Subject(ulong principal, ulong loginRole, ulong role, ulong credentialEpoch, ulong audience, Bytes context) {
            Principal = V.Counter(principal, 0); LoginRole = V.Counter(loginRole, 0); Role = V.Counter(role, 0);
            CredentialEpoch = V.Counter(credentialEpoch); Audience = V.Counter(audience); Context = Digest(context);
        }
    }
    public sealed record Column {
        public ulong Id { get; }
        public string Name { get; }
        public Logical.Descriptor Type { get; }
        public bool Nullable { get; }
        public Logical.Cell? DefaultValue { get; }
        public uint? MaxCharacters { get; }
        public Encoding Encoding { get; }
        public Collation Collation { get; }
        public Column(ulong id, string name, Logical.Descriptor type, bool nullable = true, Logical.Cell? defaultValue = null, uint? maxCharacters = null, Encoding encoding = Encoding.Plain, Collation collation = Collation.None) {
            Id = Positive(id); Name = Identifier(name); ArgumentNullException.ThrowIfNull(type); if (maxCharacters.HasValue) Positive(maxCharacters.Value); Type = type; Nullable = nullable; DefaultValue = defaultValue; MaxCharacters = maxCharacters; Logical.EnumName(encoding); Logical.EnumName(collation); Encoding = encoding; Collation = collation;
        }
        internal JsonObject Wire() { var value = ColumnWire(Name, Type, Nullable, DefaultValue, MaxCharacters, Encoding, Collation); value.Add("id", Turn.Decimal(Id)); return value; }
    }
    private sealed class WireBudget(int limit) {
        private int remaining = limit;
        internal JsonObject Take(JsonObject value) {
            remaining -= V.Utf8.GetByteCount(value.ToJsonString(CatalogJson));
            if (remaining < 0) throw new ArgumentException("Table wire budget exceeded");
            return value;
        }
    }
    private static JsonObject ColumnWire(string name, Logical.Descriptor type, bool nullable, Logical.Cell? defaultValue, uint? maxCharacters, Encoding encoding, Collation collation) => V.Obj(("name", name), ("type", Logical.TypeWire(type)), ("nullable", nullable), ("default", defaultValue is null ? null : Logical.CellWire(defaultValue)), ("max_characters", maxCharacters.HasValue ? (ulong?)maxCharacters.Value : null), ("encoding", Logical.EnumName(encoding)), ("collation", Logical.EnumName(collation)));
    public sealed record Schema {
        public ulong ObjectId { get; }
        public ulong Revision { get; }
        public ulong NextColumn { get; }
        public IReadOnlyList<Column> Columns { get; }
        public IReadOnlyList<ulong> PrimaryKey { get; }
        public Schema(ulong objectId, ulong revision, ulong nextColumn, IReadOnlyList<Column> columns, IReadOnlyList<ulong>? primaryKey = null) {
            ObjectId = Positive(objectId); Revision = Positive(revision); NextColumn = Positive(nextColumn); Columns = Logical.Own(columns, 128); PrimaryKey = Logical.Own(primaryKey ?? Array.Empty<ulong>(), Columns.Count);
            if (Columns.Count == 0 || PrimaryKey.Any(k => k == 0)) throw new ArgumentException("Invalid Table columns/keys");
        }
        internal JsonObject Wire() {
            var budget = new WireBudget(2 * 1024 * 1024);
            var value = V.Obj(("definition", ContractDefinition), ("object", Turn.Decimal(ObjectId)), ("revision", Turn.Decimal(Revision)), ("next_column", Turn.Decimal(NextColumn)),
                ("columns", new JsonArray(Columns.Select(c => (JsonNode?)budget.Take(c.Wire())).ToArray())), ("primary_key", new JsonArray(PrimaryKey.Select(k => (JsonNode?)JsonValue.Create(Turn.Decimal(k))).ToArray())));
            V.Text(value.ToJsonString(CatalogJson), 2 * 1024 * 1024); return value;
        }
    }
    public sealed record Identity {
        public ulong Operation { get; }
        public ulong Namespace { get; }
        public Identity(ulong operation, ulong @namespace = 1) { Operation = Positive(operation); Namespace = V.Counter(@namespace); }
    }
    public sealed record Counts {
        public ulong Matched { get; }
        public ulong Changed { get; }
        public Counts(ulong matched, ulong changed) { if (changed > matched) throw new ArgumentException("Changed exceeds matched"); Matched = matched; Changed = changed; }
    }
    public abstract record AssignmentValue;
    public sealed record Default : AssignmentValue;
    public sealed record CellValue : AssignmentValue { public Logical.Cell Cell { get; } public CellValue(Logical.Cell cell) { ArgumentNullException.ThrowIfNull(cell); Cell = cell; } }
    public sealed record Assignment {
        public ulong Column { get; }
        public AssignmentValue Value { get; }
        public Assignment(ulong column, AssignmentValue value) { Column = Positive(column); if (value is not (Default or CellValue)) throw new ArgumentException("Expected assignment value"); Value = value; }
        public Assignment(ulong column, Logical.Cell cell) : this(column, new CellValue(cell)) { }
        internal JsonObject Wire() => V.Obj(("column", Turn.Decimal(Column)), ("value", Value is CellValue cell ? V.Obj(("cell", Logical.CellWire(cell.Cell))) : V.Obj(("default", V.Obj()))));
    }
    public abstract record Predicate { internal abstract JsonObject Wire(); }
    public enum BooleanOperator { All, Negate, Conjunction, Disjunction }
    public sealed record BooleanPredicate : Predicate {
        public BooleanOperator Operator { get; }
        public BooleanPredicate(BooleanOperator op) { Logical.EnumName(op); Operator = op; }
        internal override JsonObject Wire() => Operator == BooleanOperator.All ? V.Obj(("atom", V.Obj(("all", V.Obj())))) : V.Obj((Logical.EnumName(Operator), V.Obj()));
    }
    public enum CellState { Missing, Null, TypeError, Value, Conflict }
    public enum CompareOperator { Eq, Ne, Lt, Le, Gt, Ge }
    public sealed record StatePredicate : Predicate {
        public ulong Column { get; }
        public CellState State { get; }
        public StatePredicate(ulong column, CellState state) { Column = Positive(column); Logical.EnumName(state); State = state; }
        internal override JsonObject Wire() => V.Obj(("atom", V.Obj(("state", V.Obj(("column", Turn.Decimal(Column)), ("value", Logical.EnumName(State)))))));
    }
    public sealed record Comparison : Predicate {
        public ulong Column { get; }
        public CompareOperator Operator { get; }
        public Logical.Atom Value { get; }
        public Comparison(ulong column, CompareOperator op, Logical.Atom value) { Column = Positive(column); Logical.EnumName(op); ArgumentNullException.ThrowIfNull(value); Operator = op; Value = value; }
        internal override JsonObject Wire() => V.Obj(("atom", V.Obj(("compare", V.Obj(("column", Turn.Decimal(Column)), ("op", Logical.EnumName(Operator)), ("value", Logical.AtomWire(Value)))))));
    }
    private static IReadOnlyList<Predicate>? Predicates(IReadOnlyList<Predicate>? values) => values is null ? null : Logical.Own(values, 64);
    private static JsonArray? PredicateWire(IReadOnlyList<Predicate>? values, WireBudget budget) => values is null ? null : new(values.Select(v => (JsonNode?)budget.Take(v.Wire())).ToArray());
    private static JsonArray AssignmentsWire(IReadOnlyList<Assignment> values, WireBudget budget) => new(values.Select(v => (JsonNode?)budget.Take(v.Wire())).ToArray());
    public abstract record Mutation { public abstract Kind Kind { get; } internal abstract JsonObject Wire(); }
    public sealed record Insert : Mutation {
        public IReadOnlyList<IReadOnlyList<Assignment>> Rows { get; }
        public Insert(IReadOnlyList<IReadOnlyList<Assignment>> rows) { Rows = Logical.Own(Logical.Own(rows, 1024).Select(r => Logical.Own(r, 128)).ToArray(), 1024); if (Rows.Count == 0) throw new ArgumentException("Empty INSERT"); }
        public override Kind Kind => Kind.Insert;
        internal override JsonObject Wire() { var budget = new WireBudget(Limit("catalog_action_bytes")); return V.Obj(("action", V.Obj(("insert", new JsonArray(Rows.Select(r => (JsonNode?)AssignmentsWire(r, budget)).ToArray())))), ("predicate", null)); }
    }
    public sealed record Update : Mutation {
        public IReadOnlyList<Assignment> Assignments { get; }
        public IReadOnlyList<Predicate>? Predicate { get; }
        public Update(IReadOnlyList<Assignment> assignments, IReadOnlyList<Predicate>? predicate = null) { Assignments = Logical.Own(assignments, 128); Predicate = Predicates(predicate); }
        public override Kind Kind => Kind.Update;
        internal override JsonObject Wire() { var budget = new WireBudget(Limit("catalog_action_bytes")); return V.Obj(("action", V.Obj(("update", AssignmentsWire(Assignments, budget)))), ("predicate", PredicateWire(Predicate, budget))); }
    }
    public sealed record Delete : Mutation {
        public IReadOnlyList<Predicate>? Predicate { get; }
        public Delete(IReadOnlyList<Predicate>? predicate = null) { Predicate = Predicates(predicate); }
        public override Kind Kind => Kind.Delete;
        internal override JsonObject Wire() => V.Obj(("action", V.Obj(("delete", V.Obj()))), ("predicate", PredicateWire(Predicate, new WireBudget(Limit("catalog_action_bytes")))));
    }
    public abstract record Change { internal abstract JsonObject Wire(); }
    public sealed record AddColumn : Change {
        public string Name { get; }
        public Logical.Descriptor Type { get; }
        public bool Nullable { get; }
        public Logical.Cell? DefaultValue { get; }
        public uint? MaxCharacters { get; }
        public Encoding Encoding { get; }
        public Collation Collation { get; }
        public AddColumn(string name, Logical.Descriptor type, bool nullable = true, Logical.Cell? defaultValue = null, uint? maxCharacters = null, Encoding encoding = Encoding.Plain, Collation collation = Collation.None) {
            _ = new Column(1, name, type, nullable, defaultValue, maxCharacters, encoding, collation); Name = name; Type = type; Nullable = nullable; DefaultValue = defaultValue; MaxCharacters = maxCharacters; Logical.EnumName(encoding); Logical.EnumName(collation); Encoding = encoding; Collation = collation;
        }
        internal override JsonObject Wire() => V.Obj(("add", ColumnWire(Name, Type, Nullable, DefaultValue, MaxCharacters, Encoding, Collation)));
    }
    public sealed record DropColumn : Change { public ulong Column { get; } public DropColumn(ulong column) { Column = Positive(column); } internal override JsonObject Wire() => V.Obj(("drop", Turn.Decimal(Column))); }
    public sealed record RenameColumn : Change {
        public ulong Column { get; }
        public string Name { get; }
        public RenameColumn(ulong column, string name) { Column = Positive(column); Name = Identifier(name); }
        internal override JsonObject Wire() => V.Obj(("rename", V.Obj(("column", Turn.Decimal(Column)), ("name", Name))));
    }
    public sealed record SetDefault : Change {
        public ulong Column { get; }
        public Logical.Cell? Value { get; }
        public SetDefault(ulong column, Logical.Cell? value) { Column = Positive(column); Value = value; }
        internal override JsonObject Wire() => V.Obj(("default", V.Obj(("column", Turn.Decimal(Column)), ("value", Value is null ? null : Logical.CellWire(Value)))));
    }
    public sealed record SetNullable : Change {
        public ulong Column { get; }
        public bool Nullable { get; }
        public SetNullable(ulong column, bool nullable) { Column = Positive(column); Nullable = nullable; }
        internal override JsonObject Wire() => V.Obj(("nullable", V.Obj(("column", Turn.Decimal(Column)), ("value", Nullable))));
    }
    public sealed record SetPhysical : Change {
        public ulong Column { get; }
        public Encoding Encoding { get; }
        public Collation Collation { get; }
        public SetPhysical(ulong column, Encoding encoding, Collation collation) { Column = Positive(column); Logical.EnumName(encoding); Logical.EnumName(collation); Encoding = encoding; Collation = collation; }
        internal override JsonObject Wire() => V.Obj(("physical", V.Obj(("column", Turn.Decimal(Column)), ("encoding", Logical.EnumName(Encoding)), ("collation", Logical.EnumName(Collation)))));
    }
    public sealed record SetType : Change {
        public ulong Column { get; }
        public Logical.Descriptor Type { get; }
        public uint? MaxCharacters { get; }
        public SetType(ulong column, Logical.Descriptor type, uint? maxCharacters = null) { Column = Positive(column); ArgumentNullException.ThrowIfNull(type); if (maxCharacters.HasValue) Positive(maxCharacters.Value); Type = type; MaxCharacters = maxCharacters; }
        internal override JsonObject Wire() => V.Obj(("type", V.Obj(("column", Turn.Decimal(Column)), ("type", Logical.TypeWire(Type)), ("max_characters", MaxCharacters.HasValue ? (ulong?)MaxCharacters.Value : null))));
    }
    public abstract record Operation { public abstract Kind Kind { get; } public abstract ulong ObjectId { get; } internal abstract JsonObject Wire(); }
    public sealed record Create : Operation {
        public Schema Schema { get; }
        public bool IfNotExists { get; }
        public Create(Schema schema, bool ifNotExists = false) { ArgumentNullException.ThrowIfNull(schema); Schema = schema; IfNotExists = ifNotExists; }
        public override Kind Kind => Kind.Create; public override ulong ObjectId => Schema.ObjectId;
        internal override JsonObject Wire() => V.Obj(("create", V.Obj(("schema", Schema.Wire()), ("if_not_exists", IfNotExists))));
    }
    public sealed record Alter : Operation {
        public Basis Basis { get; }
        public Change Change { get; }
        public Alter(Basis basis, Change change) { ArgumentNullException.ThrowIfNull(basis); ArgumentNullException.ThrowIfNull(change); Basis = basis; Change = change; }
        public override Kind Kind => Kind.Alter; public override ulong ObjectId => Basis.ObjectId;
        internal override JsonObject Wire() => V.Obj(("alter", V.Obj(("basis", Basis.Wire()), ("change", Change.Wire()))));
    }
    public sealed record Rename : Operation {
        public Basis Basis { get; }
        public string Name { get; }
        public Rename(Basis basis, string name) { ArgumentNullException.ThrowIfNull(basis); Basis = basis; Name = Identifier(name); }
        public override Kind Kind => Kind.Rename; public override ulong ObjectId => Basis.ObjectId;
        internal override JsonObject Wire() => V.Obj(("rename", V.Obj(("basis", Basis.Wire()), ("name", Name))));
    }
    public sealed record Drop : Operation {
        public Basis? Basis { get; }
        public bool IfExists { get; }
        public Drop(Basis? basis = null, bool ifExists = false) { Basis = basis; IfExists = ifExists; }
        public override Kind Kind => Kind.Drop; public override ulong ObjectId => Basis?.ObjectId ?? 0;
        internal override JsonObject Wire() => V.Obj(("drop", V.Obj(("basis", Basis?.Wire()), ("if_exists", IfExists))));
    }
    public sealed record Mutate : Operation {
        public Basis Basis { get; }
        public Mutation Mutation { get; }
        public Ingestion Ingestion { get; }
        public Mutate(Basis basis, Mutation mutation, Ingestion ingestion = Ingestion.Point) { ArgumentNullException.ThrowIfNull(basis); ArgumentNullException.ThrowIfNull(mutation); Basis = basis; Mutation = mutation; Logical.EnumName(ingestion); Ingestion = ingestion; }
        public override Kind Kind => Mutation.Kind; public override ulong ObjectId => Basis.ObjectId;
        internal override JsonObject Wire() => V.Obj(("mutate", V.Obj(("basis", Basis.Wire()), ("mutation", Mutation.Wire()), ("ingestion", Logical.EnumName(Ingestion)))));
    }
    public sealed record Position {
        public ulong Partition { get; }
        public ulong NextLsn { get; }
        public Position(ulong partition, ulong nextLsn) { Partition = Positive(partition); NextLsn = nextLsn; }
        internal JsonObject Wire() => V.Obj(("partition", Turn.Decimal(Partition)), ("next_lsn", Turn.Decimal(NextLsn)));
    }
    public sealed record ObjectIdentity {
        public Scope Scope { get; }
        public ulong Branch { get; }
        public ulong ObjectId { get; }
        public ObjectIdentity(Scope scope, ulong branch, ulong objectId) { ArgumentNullException.ThrowIfNull(scope); Scope = scope; Branch = Positive(branch); ObjectId = Positive(objectId); }
        internal JsonObject Wire() => V.Obj(("scope", Scope.Wire()), ("branch", Turn.Decimal(Branch)), ("object", Turn.Decimal(ObjectId)));
    }
    public sealed record Interpretation(ObjectIdentity Object, ulong Revision, Bytes Digest);
    public sealed record Content(ulong Bytes, Bytes Sha256);
    public sealed record StoredDefinition(Interpretation Interpretation, Content Content, Bytes SchemaFingerprint, bool Retired);
    public sealed record Configuration(Scope Scope, ulong Branch, ulong Partition, ulong Audience, AuthorityProfile Authority, string DatabaseName, string InitialSchemaName);
    public sealed record Description(Configuration Configuration, Subject Subject, ulong PolicyRevision);
    public sealed record Capabilities(uint Version, string Definition, uint MaxColumns, uint MaxRows, uint MaxSqlBytes, uint MaxIntentBytes, uint MaxActionBytes, uint MetadataPageEntries, uint ResidentIntents);
    public sealed record Metadata(Basis Basis, ulong Authorization, Position Position, ulong ChangedLsn, ulong RowCount, Schema Schema);
    public sealed record Namespace(Scope Scope, ulong Id, ulong Authorization, string Name, ulong Revision, bool Retired);
    public sealed record Entry(Interpretation Interpretation, ulong Namespace, string Name, Position Position, ulong ChangedLsn);
    public enum Consistency { Independent }
    public sealed record Page<T> {
        public Position Position { get; }
        public IReadOnlyList<T> Entries { get; }
        public Cursor? Next { get; }
        public Consistency? Consistency { get; }
        internal Page(Position position, IReadOnlyList<T> entries, Cursor? next, Consistency? consistency) {
            Position = position; Entries = Array.AsReadOnly(entries.ToArray()); Next = next; Consistency = consistency;
        }
    }
    public sealed record Commit(StoredDefinition Definition, Position Position, ulong Matched, ulong Affected, ulong LiveRows);
    public sealed record Observation(ObservationKind Kind, OperationState State, Reference Reference, Commit? Commit = null, Phase? Phase = null, Reason? Reason = null, Position? Position = null);
    public abstract record PreviewCurrent;
    public sealed record CurrentBasis(StoredDefinition Definition, Position Position, ulong ChangedLsn, ulong RowCount) : PreviewCurrent;
    public sealed record CurrentName(Interpretation Interpretation) : PreviewCurrent;
    public sealed record Preview(ObservationKind Kind, Intent Intent, Position Position, PreviewCurrent? Current, Reason? Reason = null,
        EvolutionWork? Work = null, bool? RebuildKey = null, Bytes? SchemaFingerprint = null, bool? Matches = null);
    public sealed record ReadAuthority(ulong Database, ulong Schema, ulong Table);
    public sealed record SnapshotStatus(SnapshotOwner Owner, Interpretation CurrentInterpretation, Position CurrentPosition, bool Retired, Snapshot? Snapshot, bool Released, ReadAuthority Authority);
    public sealed record SnapshotMetadata(Snapshot Snapshot, StoredDefinition Interpretation, Position Accepted, ulong ChangedLsn, ulong RowCount, Schema Schema, ReadAuthority Authority);
    public sealed record Compiled(Intent Intent, SavedIntent Saved);
    public sealed class Intent {
        private readonly string id, binding;
        public WorkKind Kind { get; }
        public Identity Identity { get; }
        public SavedIntent Saved { get; }
        internal Intent(JsonObject id, JsonObject binding, WorkKind kind, Identity identity, SavedIntent saved) {
            this.id = id.ToJsonString(CatalogJson); this.binding = binding.ToJsonString(CatalogJson); Kind = kind; Identity = identity; Saved = saved;
        }
        internal JsonObject Id() => ParseSaved(id);
        internal JsonObject Binding() => ParseSaved(binding);
        public override string ToString() => "Intent[Owned local work]";
    }
    public interface IRecovery { string Save(); }
    public abstract class SavedValue : IEquatable<SavedValue> {
        private readonly string data;
        private protected SavedValue(JsonObject value) { data = value.ToJsonString(CatalogJson); }
        public string Save() => data;
        internal JsonObject Wire() => ParseSaved(data);
        public bool Equals(SavedValue? other) => other is not null && other.GetType() == GetType() && JsonNode.DeepEquals(Wire(), other.Wire());
        public override bool Equals(object? other) => other is SavedValue value && Equals(value);
        public override int GetHashCode() => 0; // Binding equality ignores JSON object-member order.
        public override string ToString() => GetType().Name + "[Owned saved binding]";
    }
    public sealed class Basis : SavedValue {
        private Basis(JsonObject value) : base(value) { }
        public static Basis Restore(string data) {
            var v = ParseSaved(data);
            ValidateAction(V.Obj(("prepare", V.Obj(("definition", ContractDefinition), ("namespace", 1), ("operation", "1"), ("name", "check"), ("action", V.Obj(("drop", V.Obj(("basis", v), ("if_exists", false)))))))));
            Current(V.String(v["definition"])); V.Number(v["namespace"], 1); Identifier(V.String(v["name"]));
            var c = ParseConnection(v["connection"]); var stored = ParseStored(v["interpretation"]); Owns(c, stored.Interpretation.Object);
            if (stored.Retired) throw new ArgumentException("Cannot prepare from retired definition"); return new(v);
        }
        public Connection Connection => ParseConnection(Wire()["connection"]);
        public ulong Principal => V.Number(V.Object(Wire()["connection"])["principal"]);
        public ulong Namespace => V.Number(Wire()["namespace"], 1);
        public string Name => V.String(Wire()["name"]);
        public StoredDefinition Interpretation => ParseStored(Wire()["interpretation"]);
        public ulong ObjectId => Interpretation.Interpretation.Object.ObjectId;
    }
    public sealed class SavedIntent : SavedValue, IRecovery {
        private SavedIntent(JsonObject value) : base(value) { }
        public static SavedIntent Restore(string data) {
            var v = ParseSaved(data); ValidateAction(V.Obj(("load", v)));
            if (v["table"] is JsonObject table) {
                Current(V.String(table["definition"])); V.Number(table["namespace"], 1);
                if (V.Unhex(table["bytes"], Limit("catalog_intent_bytes")).Length == 0) throw new ArgumentException("Empty saved intent");
            } else CheckAssertion(V.Object(v["name_assertion"]));
            return new(v);
        }
    }
    public sealed class Reference : SavedValue, IRecovery {
        private Reference(JsonObject value) : base(value) { }
        public static Reference Restore(string data) {
            var v = ParseSaved(data); ValidateAction(V.Obj(("admit", v)));
            if (v["table"] is JsonObject table) {
                Current(V.String(table["definition"])); V.Number(table["namespace"], 1); var c = V.Object(table["connection"]);
                CheckBinding(V.Object(table["binding"]), ParseConnection(c), V.Number(c["principal"])); var content = ParseContent(table["content"]);
                if (content.Bytes <= 36 || content.Bytes > (ulong)Limit("catalog_intent_bytes")) throw new ArgumentException("Invalid saved work length");
            } else CheckAssertion(V.Object(v["name_assertion"]));
            return new(v);
        }
        public WorkKind Kind => Wire().ContainsKey("table") ? WorkKind.Table : WorkKind.NameAssertion;
        internal JsonObject Value() => V.Object(Wire()[Logical.EnumName(Kind)]);
        internal JsonObject Binding() => Kind == WorkKind.Table ? V.Object(Value()["binding"]) : Value();
        public Connection Connection => ParseConnection(Value()["connection"]);
        public ulong Principal => V.Number(V.Object(Value()["connection"])["principal"]);
        public Identity Identity => new(Wide(Kind == WorkKind.Table ? V.Object(Binding()["identity"])["operation"] : Value()["operation"]), V.Number(Value()["namespace"], 1));
    }
    public sealed class Cursor : SavedValue {
        private Cursor(JsonObject value) : base(value) { }
        public static Cursor Restore(string data) {
            var v = ParseSaved(data); var selection = V.Object(v["selection"]);
            var action = selection.ContainsKey("namespaces") ? V.Obj(("namespaces", v)) : V.Obj(("tables", V.Obj(("namespace", selection["tables"]?.DeepClone()), ("cursor", v))));
            ValidateAction(V.Obj(("catalog", action))); Current(V.String(v["definition"])); ParseConnection(v["connection"]);
            var position = ParsePosition(v["position"]); ulong after = Wide(v["after"]);
            if (position.NextLsn == 0) throw new ArgumentException("Invalid directory cut"); if (selection.ContainsKey("namespaces")) V.Counter(after);
            return new(v);
        }
        internal void Check(Connection connection, ulong principal, JsonObject selection) {
            var v = Wire(); if (!JsonNode.DeepEquals(v["connection"], connection.Wire(principal)) || !JsonNode.DeepEquals(v["selection"], selection)) throw new ArgumentException("Foreign cursor");
        }
        public Position Position => ParsePosition(Wire()["position"]);
        public ulong After => Wide(Wire()["after"]);
    }
    public sealed class SnapshotOwner : SavedValue {
        private SnapshotOwner(JsonObject value) : base(value) { }
        public static SnapshotOwner Restore(string data) {
            var v = ParseSaved(data); ValidateAction(V.Obj(("retention", V.Obj(("status", v))))); Current(V.String(v["definition"])); Wide(v["operation"]);
            Owns(ParseConnection(v["connection"]), ParseObject(v["object"])); return new(v);
        }
        public Connection Connection => ParseConnection(Wire()["connection"]);
        public ulong Principal => V.Number(V.Object(Wire()["connection"])["principal"]);
        public ObjectIdentity Object => ParseObject(Wire()["object"]);
        public ulong Operation => Wide(Wire()["operation"]);
    }
    public sealed class SnapshotAcquisition : SavedValue, IRecovery {
        private SnapshotAcquisition(JsonObject value) : base(value) { }
        public static SnapshotAcquisition Restore(string data) {
            var v = ParseSaved(data); ValidateAction(V.Obj(("retention", V.Obj(("acquire", v))))); SnapshotOwner.Restore(V.Object(v["owner"]).ToJsonString(CatalogJson)); ParsePosition(v["expected"]); return new(v);
        }
        public SnapshotOwner Owner => SnapshotOwner.Restore(V.Object(Wire()["owner"]).ToJsonString(CatalogJson));
        public Position Expected => ParsePosition(Wire()["expected"]);
    }
    public sealed class Snapshot : SavedValue, IRecovery {
        private Snapshot(JsonObject value) : base(value) { }
        public static Snapshot Restore(string data) {
            var v = ParseSaved(data); ValidateAction(V.Obj(("retention", V.Obj(("metadata", v))))); SnapshotOwner.Restore(V.Object(v["owner"]).ToJsonString(CatalogJson)); ParseContent(v["content"]); return new(v);
        }
        public SnapshotOwner Owner => SnapshotOwner.Restore(V.Object(Wire()["owner"]).ToJsonString(CatalogJson));
        public Content Content => ParseContent(Wire()["content"]);
    }
    public sealed class Uncertain : Exception {
        public IRecovery Original { get; }
        public TransitException Failure { get; }
        internal Uncertain(IRecovery original, Exception cause) : base("Catalog outcome is uncertain; retain the original saved binding", cause) {
            Original = original; Failure = cause is TransitException { Kind: ErrorKind.UnknownOutcome } error ? error : new TransitException(ErrorKind.UnknownOutcome, "catalog", 6);
        }
    }
}
