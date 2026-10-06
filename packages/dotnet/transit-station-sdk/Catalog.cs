using System.Text.Json;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using V = Transit.Client.Internal.Value;
using StationApi = Transit.Station.Sdk.Internal.NativeApi;
using StationBridge = Transit.Station.Sdk.Internal.Bridge;

namespace Transit.Station.Sdk;

/// <summary>General Table schemas, lifecycle and exact recovery over shared Zig.</summary>
public static partial class Catalog
{
    internal static readonly JsonSerializerOptions CatalogJson = new() { MaxDepth = 96 };
    internal static byte[] ActionBytes(JsonObject action) {
        string text = V.Text(action.ToJsonString(CatalogJson), Limit("catalog_action_bytes"));
        return V.Utf8.GetBytes(text);
    }
    internal static AdmissionReceipt Admission(JsonNode? value) {
        try { return new(V.Number(Fields(Result(value, "receipt"), "position")["position"], 1)); }
        catch (Exception) { throw new TransitException(ErrorKind.UnknownOutcome, "catalog-receipt", 6); }
    }
    /// <summary>Cancellation abandons a local wait; disposal joins native ownership.</summary>
    public sealed class Client : IAsyncDisposable {
        private readonly Worker<StationBridge, object?> worker;
        private readonly ulong principal;
        public Connection Connection { get; }
        private Client(Worker<StationBridge, object?> worker, Connection connection, ulong principal) { this.worker = worker; Connection = connection; this.principal = principal; }
        public static async Task<Client> OpenAsync(ClientConfig config, Credential identity, Connection connection) {
            connection.Wire(identity);
            return new(await Worker<StationBridge, object?>.OpenAsync(() => StationBridge.OpenCatalog(config, identity, connection), StationApi.MinimumStackBytes).ConfigureAwait(false), connection, identity.Principal);
        }
        private Task<T> Read<T>(JsonObject action, string field, Func<JsonNode?, T> decode, CancellationToken cancellation) {
            // Own the encoded action before queuing native work or releasing a local wait.
            byte[] bytes = ActionBytes(action);
            return worker.Invoke(b => Decode(() => decode(Result(b.Catalog(bytes), field))), cancellation);
        }
        public Task<Capabilities> CapabilitiesAsync(CancellationToken cancellation = default) => Read(V.Obj(("capabilities", V.Obj())), "capabilities", ParseCapabilities, cancellation);
        public Task<Description> DescribeAsync(CancellationToken cancellation = default) => Read(V.Obj(("describe", V.Obj())), "description", v => ParseDescription(v, Connection, principal), cancellation);
        public Task<Definition?> LookupAsync(string name, CancellationToken cancellation = default) {
            string requested = Identifier(name); return Read(V.Obj(("lookup", requested)), "definition", v => Resolved(v, Connection.Scope, requested), cancellation);
        }
        public Task<HistoricalDefinition?> DefinitionAsync(ulong objectId, ulong revision, CancellationToken cancellation = default) {
            var action = V.Obj(("definition", V.Obj(("object", Turn.Decimal(Positive(objectId))), ("revision", Turn.Decimal(Positive(revision))))));
            return Read(action, "historical", v => Historical(v, Connection.Scope, objectId, revision), cancellation);
        }
        public Task<Page> ListAsync(Cursor? cursor = null, CancellationToken cancellation = default) {
            if (cursor is not null && cursor.Scope != Connection.Scope) throw new ArgumentException("Foreign Table cursor");
            return Read(V.Obj(("list", cursor?.Wire())), "page", v => ParsePage(v, Connection.Scope, cursor), cancellation);
        }
        public Task<Compiled> CompileSqlAsync(string sql, Identity identity, ulong? createObject = null, CancellationToken cancellation = default) {
            if (V.Text(sql, 4096).Length == 0) throw new ArgumentException("Empty Table SQL");
            var action = V.Obj(("compile", V.Obj(("sql", sql), ("identity", identity.Wire()), ("create_object", createObject.HasValue ? Turn.Decimal(Positive(createObject.Value)) : null))));
            return Read(action, "compiled", v => ParseCompiled(v, Connection, principal, identity, createObject.HasValue ? Kind.Create : null, createObject), cancellation);
        }
        public Task<Compiled> PrepareAsync(string name, Identity identity, Operation operation, CancellationToken cancellation = default) {
            var action = V.Obj(("prepare", V.Obj(("definition", ContractDefinition), ("identity", identity.Wire()), ("name", Identifier(name)), ("action", operation.Wire()))));
            return Read(action, "compiled", v => ParseCompiled(v, Connection, principal, identity, operation.Kind, operation.ObjectId), cancellation);
        }
        public Task<Intent> LoadAsync(SavedIntent saved, CancellationToken cancellation = default) => Read(V.Obj(("load", saved.Wire())), "loaded", v => ParseIntent(v, Connection, principal), cancellation);
        public async Task ForgetAsync(Reference reference, CancellationToken cancellation = default) {
            await Read(V.Obj(("forget", reference.Wire())), "forgotten", v => Fields(v), cancellation).ConfigureAwait(false);
        }
        public Task<Next> NextAsync(Reference reference, CancellationToken cancellation = default) => Read(V.Obj(("next", reference.Wire())), "next", ParseNext, cancellation);
        public Task<State> StatusAsync(Reference reference, CancellationToken cancellation = default) => Read(V.Obj(("status", reference.Wire())), "state", ParseState, cancellation);
        private Task<Prepared> PrepareCommand(string name, JsonObject value, CancellationToken cancellation) => Read(V.Obj((name, value)), "prepared", ParsePrepared, cancellation);
        public Task<Prepared> PrepareResumeAsync(Reference reference, CancellationToken cancellation = default) => PrepareCommand("prepare_resume", reference.Wire(), cancellation);
        public Task<Prepared> PrepareControlAsync(Reference reference, Control control, CancellationToken cancellation = default) => PrepareCommand("prepare_control", V.Obj(("intent", reference.Wire()), ("control", Logical.EnumName(control))), cancellation);
        public Task<Prepared> PrepareInitializeAsync(Configuration value, CancellationToken cancellation = default) => PrepareCommand("prepare_initialize", value.Wire(), cancellation);
        public Task<Prepared> PreparePolicyAsync(PolicyChange value, CancellationToken cancellation = default) => PrepareCommand("prepare_policy", value.Wire(), cancellation);
        public Task<Prepared> PrepareDependencyAsync(Dependency value, bool present, CancellationToken cancellation = default) => PrepareCommand("prepare_dependency", value.Wire(present), cancellation);
        public Task<AdmissionReceipt> SubmitAsync(Prepared prepared, CancellationToken cancellation = default) {
            byte[] bytes = ActionBytes(V.Obj(("submit", prepared.Wire())));
            return worker.Invoke(b => Admission(b.Catalog(bytes)), cancellation);
        }
        private static JsonObject Input(Prepared prepared, ulong position) => V.Obj(("prepared", prepared.Wire()), ("input", V.Counter(position)));
        public Task<Observation> ObserveAsync(Prepared prepared, ulong input, bool wait = false, CancellationToken cancellation = default) => Read(V.Obj((wait ? "wait_observe" : "observe", Input(prepared, input))), "observation", Variant<Observation>, cancellation);
        public Task<Disposition?> InputDispositionAsync(Prepared prepared, ulong input, CancellationToken cancellation = default) => Read(V.Obj(("input_disposition", Input(prepared, input))), "disposition", ParseDisposition, cancellation);
        public Task<Progress> ProgressAsync(Reference reference, Prepared prepared, ulong input, bool wait = false, CancellationToken cancellation = default) {
            var value = Input(prepared, input); value.Add("intent", reference.Wire());
            return Read(V.Obj((wait ? "wait_progress" : "progress", value)), "progress", ParseProgress, cancellation);
        }
        public async ValueTask DisposeAsync() { try { await worker.CloseAsync().ConfigureAwait(false); } finally { worker.CloseSnapshot(); } }
    }
}
