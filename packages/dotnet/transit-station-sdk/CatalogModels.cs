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
    public enum Kind { Create, Alter, Rename, Drop, Insert, Update, Delete }
    public enum Phase { Preparing, Delegated, Building, Applied, Unchanged, Rejected, Cancelled }
    public enum Observation { Pending, Processed }
    public enum UploadPhase { Uploading, Sealed, Ready, Cancelled }
    public enum DispositionOutcome { Initialized, PolicyApplied, DependencyApplied, InvalidCommand, Blocked, Denied, IdentityConflict, StalePolicy }
    public enum Control { CancelOperation, CleanupOperation, CancelUpload, CollectUpload }
    public enum DependencyKind { QuerySource, Writer, Watch, MaintainedRelation, History }
    public sealed record Scope {
        public ResourceRef Resource { get; }
        public ulong CatalogId { get; }
        public Scope(ResourceRef resource, ulong catalogId) { ArgumentNullException.ThrowIfNull(resource); Resource = resource; CatalogId = Positive(catalogId); }
        internal JsonObject Wire() => V.Obj(("realm", Resource.Realm), ("resource", Resource.Resource), ("catalog", Turn.Decimal(CatalogId)));
    }
    public sealed record Connection {
        public ProcessRef Owner { get; }
        public Scope Scope { get; }
        public Connection(ProcessRef owner, Scope scope) {
            ArgumentNullException.ThrowIfNull(owner); ArgumentNullException.ThrowIfNull(scope); if (owner.Realm != scope.Resource.Realm) throw new ArgumentException("Catalog requires one realm"); Owner = owner; Scope = scope;
        }
        internal JsonObject Wire(Credential identity) {
            if (identity.Realm != Owner.Realm) throw new ArgumentException("Different credential realm"); return V.Obj(("scope", Scope.Wire()), ("owner", Owner.Pid), ("principal", identity.Principal));
        }
    }
    public sealed record TableLimits {
        public uint RecordBytes { get; }
        public ulong StagingBytes { get; }
        public uint StagingRecords { get; }
        public TableLimits(uint recordBytes, ulong stagingBytes, uint stagingRecords) { RecordBytes = Positive(recordBytes); StagingBytes = Positive(stagingBytes); StagingRecords = Positive(stagingRecords); if (stagingBytes < recordBytes) throw new ArgumentException("Staging quota cannot hold one record"); }
        internal JsonObject Wire() => V.Obj(("record_bytes", (ulong)RecordBytes), ("staging_bytes", Turn.Decimal(StagingBytes)), ("staging_records", (ulong)StagingRecords));
    }
    public sealed record Configuration {
        public Scope Scope { get; }
        public ProcessRef Owner { get; }
        public ulong Administrator { get; }
        public TableLimits TableLimits { get; }
        public Configuration(Scope scope, ProcessRef owner, ulong administrator, TableLimits tableLimits) { _ = new Connection(owner, scope); ArgumentNullException.ThrowIfNull(tableLimits); Scope = scope; Owner = owner; Administrator = V.Counter(administrator); TableLimits = tableLimits; }
        internal JsonObject Wire() => V.Obj(("scope", Scope.Wire()), ("owner", Owner.Pid), ("administrator", Administrator), ("table_limits", TableLimits.Wire()));
    }
    public sealed record Rights(bool Inspect, bool Create, bool Read, bool Insert, bool Update, bool Delete, bool Alter, bool Drop) {
        internal JsonObject Wire() => V.Obj(("inspect", Inspect), ("create", Create), ("read", Read), ("insert", Insert), ("update", Update), ("delete", Delete), ("alter", Alter), ("drop", Drop));
    }
    public sealed record Policy {
        public Scope Scope { get; }
        public ulong Principal { get; }
        public ulong Revision { get; }
        public Rights Rights { get; }
        public Policy(Scope scope, ulong principal, ulong revision, Rights rights) { ArgumentNullException.ThrowIfNull(scope); ArgumentNullException.ThrowIfNull(rights); Scope = scope; Principal = V.Counter(principal, 0); Revision = Positive(revision); Rights = rights; }
        internal JsonObject Wire() { var value = Rights.Wire(); value.Add("scope", Scope.Wire()); value.Add("principal", Principal); value.Add("revision", Turn.Decimal(Revision)); return value; }
    }
    public sealed record PolicyChange {
        public ulong ExpectedRevision { get; }
        public Policy Policy { get; }
        public PolicyChange(ulong expectedRevision, Policy policy) { ArgumentNullException.ThrowIfNull(policy); if (expectedRevision == ulong.MaxValue || policy.Revision != expectedRevision + 1) throw new ArgumentException("Expected successor policy revision"); ExpectedRevision = expectedRevision; Policy = policy; }
        internal JsonObject Wire() => V.Obj(("expected_revision", Turn.Decimal(ExpectedRevision)), ("policy", Policy.Wire()));
    }
    public sealed record Column {
        public ulong Id { get; }
        public string Name { get; }
        public Logical.Descriptor Type { get; }
        public bool Nullable { get; }
        public Logical.Cell? DefaultValue { get; }
        public uint? MaxCharacters { get; }
        public Column(ulong id, string name, Logical.Descriptor type, bool nullable = true, Logical.Cell? defaultValue = null, uint? maxCharacters = null) {
            Id = Positive(id); Name = Identifier(name); ArgumentNullException.ThrowIfNull(type); if (maxCharacters.HasValue) Positive(maxCharacters.Value); Type = type; Nullable = nullable; DefaultValue = defaultValue; MaxCharacters = maxCharacters;
        }
        internal JsonObject Wire() { var value = ColumnWire(Name, Type, Nullable, DefaultValue, MaxCharacters); value.Add("id", Turn.Decimal(Id)); return value; }
    }
    private sealed class WireBudget(int limit) {
        private int remaining = limit;
        internal JsonObject Take(JsonObject value) {
            remaining -= V.Utf8.GetByteCount(value.ToJsonString(CatalogJson));
            if (remaining < 0) throw new ArgumentException("Table wire budget exceeded");
            return value;
        }
    }
    private static JsonObject ColumnWire(string name, Logical.Descriptor type, bool nullable, Logical.Cell? defaultValue, uint? maxCharacters) => V.Obj(("name", name), ("type", Logical.TypeWire(type)), ("nullable", nullable), ("default", defaultValue is null ? null : Logical.CellWire(defaultValue)), ("max_characters", maxCharacters.HasValue ? (ulong?)maxCharacters.Value : null));
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
        public Identity(ulong operation, ulong @namespace) { Operation = Positive(operation); Namespace = Positive(@namespace); }
        internal JsonObject Wire() => V.Obj(("operation", Turn.Decimal(Operation)), ("namespace", Turn.Decimal(Namespace)));
    }
    public sealed record Basis {
        public ulong ObjectId { get; }
        public ulong Revision { get; }
        public Bytes SchemaFingerprint { get; }
        public Basis(ulong objectId, ulong revision, Bytes schemaFingerprint) { ObjectId = Positive(objectId); Revision = Positive(revision); SchemaFingerprint = Digest(schemaFingerprint); }
        internal JsonObject Wire() => V.Obj(("object", Turn.Decimal(ObjectId)), ("revision", Turn.Decimal(Revision)), ("schema_fingerprint", V.Hex(SchemaFingerprint.Copy())));
    }
    public sealed record Metadata {
        public Scope Scope { get; }
        public ulong ObjectId { get; }
        public ulong Revision { get; }
        public string Name { get; }
        public Bytes SchemaFingerprint { get; }
        public ulong Principal { get; }
        public ulong Operation { get; }
        public ulong AdmittedInput { get; }
        public Metadata(Scope scope, ulong objectId, ulong revision, string name, Bytes schemaFingerprint, ulong principal, ulong operation, ulong admittedInput) { ArgumentNullException.ThrowIfNull(scope); Scope = scope; ObjectId = Positive(objectId); Revision = Positive(revision); Name = Identifier(name); SchemaFingerprint = Digest(schemaFingerprint); Principal = V.Counter(principal, 0); Operation = Positive(operation); AdmittedInput = V.Counter(admittedInput); }
        public Basis Basis => new(ObjectId, Revision, SchemaFingerprint);
    }
    public sealed record Head {
        public ulong Revision { get; }
        public ulong Rows { get; }
        public ulong Pending { get; }
        public Head(ulong revision, ulong rows, ulong pending) { Revision = Positive(revision); Rows = rows; Pending = pending; }
    }
    public sealed record Entry(Metadata Metadata, Head Head);
    public sealed record Definition(Metadata Metadata, Head Head, Schema Schema);
    public sealed record HistoricalDefinition(Metadata Metadata, Schema Schema);
    public sealed record Cursor {
        public string Definition { get; }
        public Scope Scope { get; }
        public ulong ResourceRevision { get; }
        public ulong AfterObject { get; }
        public Cursor(string definition, Scope scope, ulong resourceRevision, ulong afterObject) { Definition = Current(definition); ArgumentNullException.ThrowIfNull(scope); Scope = scope; ResourceRevision = V.Counter(resourceRevision, 0); AfterObject = Positive(afterObject); }
        internal JsonObject Wire() => V.Obj(("definition", Definition), ("scope", Scope.Wire()), ("resource_revision", ResourceRevision), ("after_object", Turn.Decimal(AfterObject)));
    }
    public sealed record Page {
        public ulong ResourceRevision { get; }
        public IReadOnlyList<Entry> Entries { get; }
        public Cursor? Next { get; }
        public Page(ulong resourceRevision, IReadOnlyList<Entry> entries, Cursor? next) {
            ResourceRevision = V.Counter(resourceRevision, 0); Entries = Logical.Own(entries, 8); Next = next;
            for (int i = 1; i < Entries.Count; i++) if (Entries[i-1].Metadata.Scope != Entries[i].Metadata.Scope || Entries[i-1].Metadata.ObjectId >= Entries[i].Metadata.ObjectId) throw new ArgumentException("Unordered or foreign page entries");
            if (next is not null && (next.ResourceRevision != resourceRevision || (Entries.Count > 0 && (next.Scope != Entries[^1].Metadata.Scope || next.AfterObject < Entries[^1].Metadata.ObjectId)))) throw new ArgumentException("Invalid page continuation");
        }
    }
    public sealed record Reference {
        public string Definition { get; }
        public Bytes Digest { get; }
        public Reference(string definition, Bytes digest) { Definition = Current(definition); Digest = Catalog.Digest(digest); }
        internal JsonObject Wire() => V.Obj(("definition", Definition), ("digest", V.Hex(Digest.Copy())));
    }
    public sealed record SavedIntent {
        public string Definition { get; }
        private readonly byte[] bytes;
        public SavedIntent(string definition, byte[] bytes) { Definition = Current(definition); this.bytes = V.Bytes(bytes, Limit("catalog_intent_bytes")); if (bytes.Length == 0) throw new ArgumentException("Empty Table intent"); }
        public byte[] Copy() => (byte[])bytes.Clone();
        public bool Equals(SavedIntent? other) => other is not null && Definition == other.Definition && bytes.AsSpan().SequenceEqual(other.bytes);
        public override int GetHashCode() { HashCode hash = new(); hash.Add(Definition); hash.AddBytes(bytes); return hash.ToHashCode(); }
        public override string ToString() => $"SavedIntent[OwnedBytes={bytes.Length}]";
        internal JsonObject Wire() => V.Obj(("definition", Definition), ("bytes", V.Hex(bytes)));
    }
    public sealed record Prepared {
        public Bytes Bytes { get; }
        public Prepared(Bytes bytes) { ArgumentNullException.ThrowIfNull(bytes); if (bytes.Length == 0 || bytes.Length > Limit("catalog_prepared_bytes")) throw new ArgumentException("Invalid prepared Table length"); _ = V.Utf8.GetString(bytes.Copy()); Bytes = bytes; }
        internal string Wire() => V.Utf8.GetString(Bytes.Copy());
        public override string ToString() => "Prepared[Owned signed command]";
    }
    public sealed record Intent(Reference Reference, Scope Scope, ProcessRef Owner, ulong Principal, Identity Identity, ulong ObjectId, Kind Kind);
    public sealed record Compiled(Intent Intent, SavedIntent Saved);
    public sealed record Counts {
        public ulong Matched { get; }
        public ulong Changed { get; }
        public Counts(ulong matched, ulong changed) { if (changed > matched) throw new ArgumentException("Changed exceeds matched"); Matched = matched; Changed = changed; }
    }
    // Exact generated JSON is privately retained; callers receive independent trees.
    public sealed class Diagnostic : IEquatable<Diagnostic> {
        private readonly JsonObject value;
        public Diagnostic(JsonObject value) {
            V.Text(value.ToJsonString(), 32768);
            Transit.Client.Internal.Schema.Require(V.Object(V.Object(V.Contract["schemas"])["Diagnostic"]), value);
            this.value = value.DeepClone().AsObject();
        }
        public JsonObject Copy() => value.DeepClone().AsObject();
        public bool Equals(Diagnostic? other) => other is not null && JsonNode.DeepEquals(value, other.value);
        public override bool Equals(object? other) => other is Diagnostic diagnostic && Equals(diagnostic);
        public override int GetHashCode() => 0; // Equality includes objects independent of member order.
        public override string ToString() => "Diagnostic[Owned evidence]";
    }
    public sealed record Outcome(Kind Kind, ulong Operation, ulong ObjectId, ulong? ActualObject, Phase Phase, bool Terminal, Counts? Counts, ulong AdmittedInput, ulong? CompletedInput, Diagnostic Diagnostic);
    public sealed record Upload(UploadPhase Phase, uint Received, uint Total);
    public sealed record State(Outcome? Outcome, Upload? Upload);
    public sealed record Disposition(ulong Input, DispositionOutcome Outcome, Diagnostic Diagnostic);
    public enum NextKind { Send, Running, Terminal, UploadCancelled }
    public sealed record Next(NextKind Kind, Prepared? Prepared = null, Outcome? Outcome = null);
    public sealed record Progress(Observation Observation, Disposition? Disposition = null, Outcome? Outcome = null, Upload? Upload = null);
    public sealed record Capabilities(uint Version, string Definition, uint MaxColumns, uint MaxRows, uint MaxSqlBytes, uint MaxIntentBytes, uint MaxActionBytes, uint MaxPreparedBytes, uint ResidentIntents);
    public sealed record Description(Configuration Configuration, Policy Policy, ulong ResourceRevision);
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
        public AddColumn(string name, Logical.Descriptor type, bool nullable = true, Logical.Cell? defaultValue = null, uint? maxCharacters = null) {
            _ = new Column(1, name, type, nullable, defaultValue, maxCharacters); Name = name; Type = type; Nullable = nullable; DefaultValue = defaultValue; MaxCharacters = maxCharacters;
        }
        internal override JsonObject Wire() => V.Obj(("add", ColumnWire(Name, Type, Nullable, DefaultValue, MaxCharacters)));
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
        public Mutate(Basis basis, Mutation mutation) { ArgumentNullException.ThrowIfNull(basis); ArgumentNullException.ThrowIfNull(mutation); Basis = basis; Mutation = mutation; }
        public override Kind Kind => Mutation.Kind; public override ulong ObjectId => Basis.ObjectId;
        internal override JsonObject Wire() => V.Obj(("mutate", V.Obj(("basis", Basis.Wire()), ("mutation", Mutation.Wire()))));
    }
    public sealed record Dependency {
        public Scope Scope { get; }
        public ulong ObjectId { get; }
        public ulong Identity { get; }
        public ProcessRef Owner { get; }
        public DependencyKind Kind { get; }
        public Dependency(Scope scope, ulong objectId, ulong identity, ProcessRef owner, DependencyKind kind) { _ = new Connection(owner, scope); Logical.EnumName(kind); Scope = scope; ObjectId = Positive(objectId); Identity = Positive(identity); Owner = owner; Kind = kind; }
        internal JsonObject Wire(bool present) => V.Obj(("scope", Scope.Wire()), ("object", Turn.Decimal(ObjectId)), ("identity", Turn.Decimal(Identity)), ("owner", Owner.Pid), ("kind", Logical.EnumName(Kind)), ("present", present));
    }
}
