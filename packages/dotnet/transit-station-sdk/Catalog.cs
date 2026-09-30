using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;
using V = Transit.Client.Internal.Value;
using StationApi = Transit.Station.Sdk.Internal.NativeApi;
using StationBridge = Transit.Station.Sdk.Internal.Bridge;

namespace Transit.Station.Sdk;

/// <summary>Typed catalog values and owned asynchronous callers over shared Zig.</summary>
public static class Catalog
{
    private static ulong Positive(ulong value) => value == 0 ? throw new ArgumentException("Expected positive catalog identity") : value;
    private static string Identifier(string value) => V.Text(value, 16).Length == 0 ? throw new ArgumentException("Empty catalog name") : value;
    private static string MetadataName(string value) {
        Identifier(value);
        static bool Letter(char c) => c is >= 'A' and <= 'Z' or >= 'a' and <= 'z' or '_';
        if (!Letter(value[0]) || value.Any(c => !Letter(c) && c is not (>= '0' and <= '9'))) throw new ArgumentException("Expected ASCII catalog name");
        return value;
    }
    private static string Name<T>(T value) where T : struct, Enum {
        if (!Enum.IsDefined(value)) throw new ArgumentException("Invalid catalog variant");
        return string.Concat(value.ToString().Select((c, i) => (i > 0 && char.IsUpper(c) ? "_" : "") + char.ToLowerInvariant(c)));
    }
    private static T Variant<T>(JsonNode? value) where T : struct, Enum {
        string name = V.String(value);
        foreach (T item in Enum.GetValues<T>()) if (Name(item) == name) return item;
        throw V.Incompatible("catalog-variant");
    }
    private static JsonObject Fields(JsonNode? value, params string[] names) {
        var result = V.Object(value);
        if (result.Count != names.Length || names.Any(name => !result.ContainsKey(name))) throw V.Incompatible("catalog-fields");
        return result;
    }
    private static JsonNode? Result(JsonNode? value, string key) => Fields(value, key)[key];
    public enum Type { Int64, Boolean, Utf8, Binary }
    public enum Observation { Pending, Processed }
    public enum Outcome { Applied, NameConflict, ObjectConflict, TableConflict }
    public enum Origin { External, Process, Effect }
    public enum DispositionOutcome { Initialized, PolicyApplied, InvalidCommand, Denied, IdentityConflict, StalePolicy }
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
            ArgumentNullException.ThrowIfNull(owner); ArgumentNullException.ThrowIfNull(scope);
            if (owner.Realm != scope.Resource.Realm) throw new ArgumentException("Catalog requires one realm");
            Owner = owner; Scope = scope;
        }
        internal JsonObject Wire(Credential identity) {
            if (identity.Realm != Owner.Realm) throw new ArgumentException("Different credential realm");
            return V.Obj(("scope", Scope.Wire()), ("owner", Owner.Pid), ("principal", identity.Principal));
        }
    }
    public sealed record Configuration {
        public Scope Scope { get; }
        public ProcessRef Owner { get; }
        public ulong Administrator { get; }
        public Configuration(Scope scope, ProcessRef owner, ulong administrator) {
            _ = new Connection(owner, scope); Scope = scope; Owner = owner; Administrator = V.Counter(administrator);
        }
        internal JsonObject Wire() => V.Obj(("scope", Scope.Wire()), ("owner", Owner.Pid), ("administrator", Administrator));
    }
    public sealed record Schema {
        public IReadOnlyList<string> Names { get; }
        public Type ValueType { get; }
        public Schema(IReadOnlyList<string> names, Type valueType) {
            ArgumentNullException.ThrowIfNull(names);
            if (names.Count != 2 || !Enum.IsDefined(valueType)) throw new ArgumentException("Catalog requires two column names and a supported type");
            Names = Array.AsReadOnly(new[] { Identifier(names[0]), Identifier(names[1]) }); ValueType = valueType;
        }
        public bool Equals(Schema? other) => other is not null && ValueType == other.ValueType && Names.SequenceEqual(other.Names);
        public override int GetHashCode() => HashCode.Combine(ValueType, Names[0], Names[1]);
        internal JsonObject Wire() => V.Obj(("names", new JsonArray(Names.Select(n => (JsonNode?)JsonValue.Create(n)).ToArray())), ("value_type", Name(ValueType)));
    }
    public sealed record CreateTable {
        public Scope Scope { get; }
        public ulong Operation { get; }
        public ulong ObjectId { get; }
        public uint Table { get; }
        public string Name { get; }
        public Schema Schema { get; }
        public CreateTable(Scope scope, ulong operation, ulong objectId, uint table, string name, Schema schema) {
            ArgumentNullException.ThrowIfNull(scope); ArgumentNullException.ThrowIfNull(schema);
            if (table == 0) throw new ArgumentException("Invalid catalog Table identity");
            Scope = scope; Operation = Positive(operation); ObjectId = Positive(objectId); Table = table; Name = Identifier(name); Schema = schema;
        }
        internal JsonObject Wire() => V.Obj(("scope", Scope.Wire()), ("operation", Turn.Decimal(Operation)), ("object", Turn.Decimal(ObjectId)), ("table", Table), ("name", Name), ("schema", Schema.Wire()));
    }
    public sealed record Policy {
        public Scope Scope { get; }
        public ulong Principal { get; }
        public ulong Revision { get; }
        public bool Inspect { get; }
        public bool Create { get; }
        public Policy(Scope scope, ulong principal, ulong revision, bool inspect, bool create) {
            ArgumentNullException.ThrowIfNull(scope); Scope = scope; Principal = V.Counter(principal, 0); Revision = Positive(revision); Inspect = inspect; Create = create;
        }
        internal JsonObject Wire() => V.Obj(("scope", Scope.Wire()), ("principal", Principal), ("revision", Turn.Decimal(Revision)), ("inspect", Inspect), ("create", Create));
    }
    public sealed record PolicyChange {
        public ulong ExpectedRevision { get; }
        public Policy Policy { get; }
        public PolicyChange(ulong expectedRevision, Policy policy) { ArgumentNullException.ThrowIfNull(policy); ExpectedRevision = expectedRevision; Policy = policy; }
        internal JsonObject Wire() => V.Obj(("expected_revision", Turn.Decimal(ExpectedRevision)), ("policy", Policy.Wire()));
    }
    public sealed record Compiled {
        public CreateTable Request { get; }
        public Bytes Canonical { get; }
        public Compiled(CreateTable request, Bytes canonical) {
            ArgumentNullException.ThrowIfNull(request); ArgumentNullException.ThrowIfNull(canonical);
            if (canonical.Length == 0 || canonical.Length > 256) throw new ArgumentException("Invalid catalog canonical length");
            Request = request; Canonical = canonical;
        }
    }
    /// <summary>Save exact bytes before submission or awaiting its Task.</summary>
    public sealed record Prepared {
        public Bytes Bytes { get; }
        public Prepared(Bytes bytes) {
            ArgumentNullException.ThrowIfNull(bytes);
            if (bytes.Length == 0 || bytes.Length > 8192) throw new ArgumentException("Invalid saved catalog length");
            _ = V.Utf8.GetString(bytes.Copy()); Bytes = bytes;
        }
        internal string Wire() => V.Utf8.GetString(Bytes.Copy());
    }
    public sealed record Capabilities(byte Version, string Definition, bool Initialize, bool CreateTable, bool ConditionalPolicy, bool CurrentMetadata, ushort MaxSavedBytes, byte TableColumns);
    public sealed record Description(Configuration Configuration, Policy Policy, ulong ResourceRevision);
    public sealed record TableSource {
        public uint Table { get; }
        public Schema Schema { get; }
        public TableSource(uint table, Schema schema) {
            ArgumentNullException.ThrowIfNull(schema);
            if (table == 0 || schema.Names[0] == schema.Names[1]) throw new ArgumentException("Invalid catalog Table source");
            foreach (string name in schema.Names) MetadataName(name);
            Table = table; Schema = schema;
        }
    }
    public sealed record Definition {
        public Scope Scope { get; }
        public ulong ObjectId { get; }
        public ulong Revision { get; }
        public string Name { get; }
        public TableSource Source { get; }
        public ulong Principal { get; }
        public ulong Operation { get; }
        public ulong Input { get; }
        public Definition(Scope scope, ulong objectId, ulong revision, string name, TableSource source, ulong principal, ulong operation, ulong input) {
            ArgumentNullException.ThrowIfNull(scope); ArgumentNullException.ThrowIfNull(source);
            Scope = scope; ObjectId = Positive(objectId); Revision = Positive(revision); Name = MetadataName(name); Source = source;
            Principal = V.Counter(principal, 0); Operation = Positive(operation); Input = V.Counter(input);
        }
    }
    /// <summary>Persist all original fields; compatibility definition is mandatory.</summary>
    public sealed record Cursor {
        public string Definition { get; }
        public Scope Scope { get; }
        public ulong ResourceRevision { get; }
        public string After { get; }
        public Cursor(string definition, Scope scope, ulong resourceRevision, string after) {
            if (definition != StationApi.Definition) throw new ArgumentException("Foreign catalog cursor definition");
            ArgumentNullException.ThrowIfNull(scope); Definition = definition; Scope = scope;
            ResourceRevision = V.Counter(resourceRevision); After = MetadataName(after);
        }
        internal JsonObject Wire() => V.Obj(("definition", Definition), ("scope", Scope.Wire()), ("resource_revision", ResourceRevision), ("after", After));
    }
    public sealed record Page {
        public ulong ResourceRevision { get; }
        public IReadOnlyList<Definition> Entries { get; }
        public Cursor? Next { get; }
        public Page(ulong resourceRevision, IReadOnlyList<Definition> entries, Cursor? next) {
            ArgumentNullException.ThrowIfNull(entries); ResourceRevision = V.Counter(resourceRevision);
            if (entries.Count > 8 || entries.Any(e => e is null)) throw new ArgumentException("Expected at most eight definitions");
            var owned = entries.ToArray();
            for (int i = 1; i < owned.Length; i++)
                if (owned[i-1].Scope != owned[i].Scope || string.CompareOrdinal(owned[i-1].Name, owned[i].Name) >= 0) throw new ArgumentException("Expected ordered definitions in one scope");
            if (next is not null && (owned.Length == 0 || next.Scope != owned[^1].Scope || next.After != owned[^1].Name || next.ResourceRevision != resourceRevision)) throw new ArgumentException("Cursor differs from catalog page");
            Entries = Array.AsReadOnly(owned); Next = next;
        }
        public bool Equals(Page? other) => other is not null && ResourceRevision == other.ResourceRevision && Next == other.Next && Entries.SequenceEqual(other.Entries);
        public override int GetHashCode() { HashCode hash = new(); hash.Add(ResourceRevision); hash.Add(Next); foreach (var entry in Entries) hash.Add(entry); return hash.ToHashCode(); }
    }
    public sealed record Receipt(CreateTable Request, ulong Principal, ulong Input, Outcome Outcome);
    public sealed record Disposition(Scope Scope, Origin Origin, ulong Principal, ulong Input, Bytes Payload, DispositionOutcome Outcome);
    private static Scope ParseScope(JsonNode? value) {
        var v = Fields(value, "realm", "resource", "catalog");
        return new(new ResourceRef(V.Number(v["realm"], 1), V.Number(v["resource"], 1)), NativeValues.Wide(v["catalog"], true));
    }
    private static Configuration ParseConfiguration(JsonNode? value) {
        var v = Fields(value, "scope", "owner", "administrator"); var scope = ParseScope(v["scope"]);
        return new(scope, new ProcessRef(scope.Resource.Realm, V.Number(v["owner"], 1)), V.Number(v["administrator"], 1));
    }
    private static Policy ParsePolicy(JsonNode? value) {
        var v = Fields(value, "scope", "principal", "revision", "inspect", "create");
        return new(ParseScope(v["scope"]), V.Number(v["principal"]), NativeValues.Wide(v["revision"], true), V.Boolean(v["inspect"]), V.Boolean(v["create"]));
    }
    private static CreateTable ParseRequest(JsonNode? value) {
        var v = Fields(value, "scope", "operation", "object", "table", "name", "schema"); var schema = Fields(v["schema"], "names", "value_type");
        if (schema["names"] is not JsonArray { Count: 2 } names) throw V.Incompatible("catalog-columns");
        return new(ParseScope(v["scope"]), NativeValues.Wide(v["operation"], true), NativeValues.Wide(v["object"], true), checked((uint)V.Number(v["table"], 1)), V.String(v["name"]), new Schema(names.Select(n => V.String(n)).ToArray(), Variant<Type>(schema["value_type"])));
    }
    private static T Metadata<T>(Func<T> decode) {
        try { return decode(); }
        catch (Exception error) when (error is ArgumentException or InvalidOperationException or OverflowException) { throw V.Incompatible("catalog-metadata"); }
    }
    private static Definition? ParseDefinition(JsonNode? value) {
        if (value is null) return null;
        var v = Fields(value, "scope", "object", "revision", "name", "source", "principal", "operation", "input");
        var table = Fields(Fields(v["source"], "table")["table"], "id", "schema"); var schema = Fields(table["schema"], "names", "value_type");
        if (schema["names"] is not JsonArray { Count: 2 } names) throw V.Incompatible("catalog-columns");
        TableSource source = new(checked((uint)V.Number(table["id"], 1)), new Schema(names.Select(n => V.String(n)).ToArray(), Variant<Type>(schema["value_type"])));
        return new(ParseScope(v["scope"]), NativeValues.Wide(v["object"], true), NativeValues.Wide(v["revision"], true), V.String(v["name"]), source, V.Number(v["principal"]), NativeValues.Wide(v["operation"], true), V.Number(v["input"], 1));
    }
    internal static Definition? Resolved(JsonNode? value, Scope scope, string? name, ulong? objectId, ulong? revision) => Metadata(() => {
        var found = ParseDefinition(value);
        if (found is not null && (found.Scope != scope || (name is not null && found.Name != name) || (objectId is not null && found.ObjectId != objectId) || (revision is not null && found.Revision != revision))) throw V.Incompatible("catalog-request-identity");
        return found;
    });
    private static Cursor? ParseCursor(JsonNode? value) {
        if (value is null) return null;
        var v = Fields(value, "definition", "scope", "resource_revision", "after");
        return new(V.String(v["definition"]), ParseScope(v["scope"]), V.Number(v["resource_revision"], 1), V.String(v["after"]));
    }
    internal static Page ParsePage(JsonNode? value, Scope scope, Cursor? previous) => Metadata(() => {
        var v = Fields(value, "resource_revision", "entries", "next");
        if (v["entries"] is not JsonArray { Count: 8 } slots) throw V.Incompatible("catalog-page-slots");
        List<Definition> entries = []; bool ended = false;
        foreach (var slot in slots) {
            var entry = ParseDefinition(slot);
            if (entry is null) ended = true;
            else { if (ended || entry.Scope != scope) throw V.Incompatible("catalog-page-scope"); entries.Add(entry); }
        }
        Page page = new(V.Number(v["resource_revision"], 1), entries, ParseCursor(v["next"]));
        if (previous is not null && (page.ResourceRevision != previous.ResourceRevision || (entries.Count > 0 && string.CompareOrdinal(entries[0].Name, previous.After) <= 0))) throw V.Incompatible("catalog-continuation");
        return page;
    });
    internal static Capabilities ParseCapabilities(JsonNode? value) {
        var v = Fields(value, "version", "definition", "initialize", "create_table", "conditional_policy", "current_metadata", "max_saved_bytes", "table_columns");
        if (V.Number(v["version"], 1) != 1 || V.String(v["definition"]) != StationApi.Definition || V.Number(v["max_saved_bytes"], 1) != 8192 || V.Number(v["table_columns"], 1) != 2) throw V.Incompatible("catalog-capabilities");
        return new(1, V.String(v["definition"]), V.Boolean(v["initialize"]), V.Boolean(v["create_table"]), V.Boolean(v["conditional_policy"]), V.Boolean(v["current_metadata"]), 8192, 2);
    }
    private static Prepared ParsePrepared(JsonNode? value) => new(new Bytes(V.Utf8.GetBytes(V.String(value))));
    internal static AdmissionReceipt Admission(JsonNode? value) {
        try { return new(V.Number(Fields(Result(value, "receipt"), "position")["position"], 1)); }
        catch (Exception) { throw new TransitException(ErrorKind.UnknownOutcome, "catalog-receipt", 6); }
    }
    internal static Receipt ParseReceipt(JsonNode? value, CreateTable original) {
        var v = Fields(value, "request", "principal", "input", "outcome"); var actual = ParseRequest(v["request"]);
        if (actual != original) throw V.Incompatible("catalog-original-request");
        return new(actual, V.Number(v["principal"]), V.Number(v["input"], 1), Variant<Outcome>(v["outcome"]));
    }
    /// <summary>Cancellation abandons a local wait; disposal joins native ownership.</summary>
    public sealed class Client : IAsyncDisposable {
        private readonly Worker<StationBridge, object?> worker;
        public Connection Connection { get; }
        private Client(Worker<StationBridge, object?> worker, Connection connection) { this.worker = worker; Connection = connection; }
        public static async Task<Client> OpenAsync(ClientConfig config, Credential identity, Connection connection) {
            connection.Wire(identity);
            return new(await Worker<StationBridge, object?>.OpenAsync(() => StationBridge.OpenCatalog(config, identity, connection), StationApi.MinimumStackBytes).ConfigureAwait(false), connection);
        }
        public Task<Capabilities> CapabilitiesAsync(CancellationToken cancellation = default) => worker.Invoke(b => ParseCapabilities(Result(b.Catalog(V.Obj(("capabilities", V.Obj()))), "capabilities")), cancellation);
        public Task<Description> DescribeAsync(CancellationToken cancellation = default) => worker.Invoke(b => {
            var v = Fields(Result(b.Catalog(V.Obj(("describe", V.Obj()))), "description"), "configuration", "policy", "resource_revision");
            return new Description(ParseConfiguration(v["configuration"]), ParsePolicy(v["policy"]), V.Number(v["resource_revision"]));
        }, cancellation);
        public Task<Definition?> LookupAsync(string name, CancellationToken cancellation = default) {
            string requested = MetadataName(name); var action = V.Obj(("lookup", requested));
            return worker.Invoke(b => Resolved(Result(b.Catalog(action), "definition"), Connection.Scope, requested, null, null), cancellation);
        }
        public Task<Definition?> DefinitionAsync(ulong objectId, ulong revision, CancellationToken cancellation = default) {
            var action = V.Obj(("definition", V.Obj(("object", Turn.Decimal(Positive(objectId))), ("revision", Turn.Decimal(Positive(revision))))));
            return worker.Invoke(b => Resolved(Result(b.Catalog(action), "definition"), Connection.Scope, null, objectId, revision), cancellation);
        }
        public Task<Page> ListAsync(Cursor? cursor = null, CancellationToken cancellation = default) {
            var action = V.Obj(("list", cursor?.Wire()));
            return worker.Invoke(b => ParsePage(Result(b.Catalog(action), "page"), Connection.Scope, cursor), cancellation);
        }
        public Task<Compiled> CompileSqlAsync(string sql, ulong operation, ulong objectId, uint table, CancellationToken cancellation = default) {
            if (V.Text(sql, 4096).Length == 0 || table == 0) throw new ArgumentException("Invalid catalog compilation");
            var action = V.Obj(("compile", V.Obj(("sql", sql), ("operation", Turn.Decimal(Positive(operation))), ("object", Turn.Decimal(Positive(objectId))), ("table", table))));
            return worker.Invoke(b => { var v = Fields(Result(b.Catalog(action), "compiled"), "request", "canonical"); return new Compiled(ParseRequest(v["request"]), new Bytes(V.Unhex(v["canonical"], 256))); }, cancellation);
        }
        private Task<Prepared> Prepare(string name, JsonObject value, CancellationToken cancellation) {
            var action = V.Obj((name, value)); return worker.Invoke(b => ParsePrepared(Result(b.Catalog(action), "prepared")), cancellation);
        }
        public Task<Prepared> PrepareInitializeAsync(Configuration configuration, CancellationToken cancellation = default) => Prepare("prepare_initialize", configuration.Wire(), cancellation);
        public Task<Prepared> PrepareCreateAsync(CreateTable request, CancellationToken cancellation = default) => Prepare("prepare_create", request.Wire(), cancellation);
        public Task<Prepared> PreparePolicyAsync(PolicyChange change, CancellationToken cancellation = default) => Prepare("prepare_policy", change.Wire(), cancellation);
        public Task<AdmissionReceipt> SubmitAsync(Prepared prepared, CancellationToken cancellation = default) {
            var action = V.Obj(("submit", prepared.Wire())); return worker.Invoke(b => Admission(b.Catalog(action)), cancellation);
        }
        private static JsonObject Input(string name, Prepared prepared, ulong position) => V.Obj((name, V.Obj(("prepared", prepared.Wire()), ("input", V.Counter(position)))));
        public Task<Observation> ObserveAsync(Prepared prepared, ulong input, CancellationToken cancellation = default) {
            var action = Input("observe", prepared, input); return worker.Invoke(b => Variant<Observation>(Result(b.Catalog(action), "observation")), cancellation);
        }
        public Task<Disposition?> InputDispositionAsync(Prepared prepared, ulong input, CancellationToken cancellation = default) {
            var action = Input("input_disposition", prepared, input);
            return worker.Invoke<Disposition?>(b => {
                var value = Result(b.Catalog(action), "disposition"); if (value is null) return null;
                var v = Fields(value, "scope", "origin", "principal", "input", "payload", "outcome"); Bytes payload = new(V.Unhex(v["payload"], 32));
                if (payload.Length != 32) throw V.Incompatible("catalog-payload");
                return new(ParseScope(v["scope"]), Variant<Origin>(v["origin"]), V.Number(v["principal"]), V.Number(v["input"], 1), payload, Variant<DispositionOutcome>(v["outcome"]));
            }, cancellation);
        }
        public Task<Receipt?> StatusAsync(CreateTable original, CancellationToken cancellation = default) {
            var action = V.Obj(("status", original.Wire())); return worker.Invoke<Receipt?>(b => Result(b.Catalog(action), "status") is {} v ? ParseReceipt(v, original) : null, cancellation);
        }
        public async ValueTask DisposeAsync() { try { await worker.CloseAsync().ConfigureAwait(false); } finally { worker.CloseSnapshot(); } }
    }
}
