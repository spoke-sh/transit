using System.Text.Json;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using V = Transit.Client.Internal.Value;
using StationApi = Transit.Station.Sdk.Internal.NativeApi;
using StationBridge = Transit.Station.Sdk.Internal.Bridge;

namespace Transit.Station.Sdk;

/// <summary>Direct lifecycle values and scheduling; shared Zig owns authority and recovery.</summary>
public static partial class Catalog
{
    internal static readonly JsonSerializerOptions CatalogJson = new() { MaxDepth = 96 };
    internal static byte[] ActionBytes(JsonObject action) {
        ValidateAction(action); return V.Utf8.GetBytes(V.Text(action.ToJsonString(CatalogJson), Limit("catalog_action_bytes")));
    }
    public sealed class Client : IAsyncDisposable {
        private readonly Worker<StationBridge, object?> worker;
        private readonly ulong principal;
        public Connection Connection { get; }
        private Client(Worker<StationBridge, object?> worker, Connection connection, ulong principal) { this.worker = worker; Connection = connection; this.principal = principal; }
        public static async Task<Client> OpenAsync(ClientConfig config, Credential identity, Connection connection, string? serviceUrl = null) {
            connection.Wire(identity);
            if (serviceUrl is not null) { V.Text(serviceUrl, 2048); _ = new ClientConfig(new Uri(serviceUrl, UriKind.Absolute), Profile.NativeV1); }
            return new(await Worker<StationBridge, object?>.OpenAsync(() => StationBridge.OpenCatalog(config, identity, connection, serviceUrl), StationApi.MinimumStackBytes).ConfigureAwait(false), connection, identity.Principal);
        }
        private Task<T> Read<T>(JsonObject action, IRecovery? original, Func<JsonNode?,T> decode, CancellationToken cancellation, params string[] path) {
            byte[] bytes = ActionBytes(action);
            return worker.Invoke(bridge => {
                JsonObject response;
                try { response = bridge.Catalog(bytes); }
                catch (TransitException error) when (original is not null && error.Kind == ErrorKind.UnknownOutcome) { throw new Uncertain(original,error); }
                catch (OutOfMemoryException error) when (original is not null) { throw new Uncertain(original,error); }
                try { return Decode(() => { ValidateResponse(response); return decode(Path(response,path)); }); }
                catch (Exception error) when (original is not null) { throw new Uncertain(original,error); }
            },cancellation);
        }
        private void Owner(Connection connection, ulong owner) { if (connection != Connection || owner != principal) throw new ArgumentException("Foreign catalog caller"); }
        public Task<Capabilities> CapabilitiesAsync(CancellationToken cancellation = default) => Read(V.Obj(("catalog",V.Obj(("capabilities",V.Obj())))),null,ParseCapabilities,cancellation,"catalog","capabilities");
        public Task<Description> DescribeAsync(CancellationToken cancellation = default) => Read(V.Obj(("catalog",V.Obj(("describe",V.Obj())))),null,v => ParseDescription(v,Connection,principal),cancellation,"catalog","description");
        public Task<Namespace?> NamespaceAsync(ulong id, CancellationToken cancellation = default) {
            V.Counter(id); return Read<Namespace?>(V.Obj(("catalog",V.Obj(("namespace",id)))),null,v => {
                if (v is null) return null; var found = ParseNamespace(v); if (found.Id != id || found.Scope != Connection.Scope) throw V.Incompatible("catalog-namespace"); return found;
            },cancellation,"catalog","namespace");
        }
        public Task<Page<Namespace>> NamespacesAsync(Cursor? cursor = null, CancellationToken cancellation = default) {
            cursor?.Check(Connection,principal,V.Obj(("namespaces",V.Obj())));
            return Read(V.Obj(("catalog",V.Obj(("namespaces",cursor?.Wire())))),null,v => ParseNamespaces(v,Connection,principal,cursor),cancellation,"catalog","namespaces");
        }
        public Task<Page<Entry>> TablesAsync(ulong schemaNamespace = 1, Cursor? cursor = null, CancellationToken cancellation = default) {
            V.Counter(schemaNamespace); cursor?.Check(Connection,principal,V.Obj(("tables",schemaNamespace)));
            return Read(V.Obj(("catalog",V.Obj(("tables",V.Obj(("namespace",schemaNamespace),("cursor",cursor?.Wire())))))),null,v => ParseTables(v,Connection,principal,schemaNamespace,cursor),cancellation,"catalog","tables");
        }
        public Task<Metadata?> LookupAsync(string name, ulong schemaNamespace = 1, CancellationToken cancellation = default) {
            Identifier(name); V.Counter(schemaNamespace);
            return Read<Metadata?>(V.Obj(("lookup",V.Obj(("namespace",schemaNamespace),("name",name)))),null,v => v is null ? null : ParseMetadata(v,Connection,principal,schemaNamespace,name),cancellation,"metadata");
        }
        private Task<Compiled> Compiled(JsonObject action, Identity identity, CancellationToken cancellation) => Read(action,null,value => {
            var v = V.Object(value); var saved = SavedIntent.Restore(V.Object(v["saved"]).ToJsonString(CatalogJson)); return new Compiled(ParseSummary(v["summary"],saved,Connection,principal,identity),saved);
        },cancellation,"compiled");
        public Task<Compiled> CompileSqlAsync(string sql, Identity identity, ulong? createObject = null, Dialect dialect = Dialect.Transit, Ingestion ingestion = Ingestion.Point, CancellationToken cancellation = default) {
            if (V.Text(sql,4096).Length == 0) throw new ArgumentException("Empty SQL");
            return Compiled(V.Obj(("compile",V.Obj(("sql",sql),("namespace",identity.Namespace),("operation",Turn.Decimal(identity.Operation)),
                ("create_object",createObject is {} id ? Turn.Decimal(Positive(id)) : null),("dialect",Logical.EnumName(dialect)),("ingestion",Logical.EnumName(ingestion))))),identity,cancellation);
        }
        public Task<Compiled> PrepareAsync(string name, Identity identity, Operation operation, CancellationToken cancellation = default) => Compiled(
            V.Obj(("prepare",V.Obj(("definition",ContractDefinition),("namespace",identity.Namespace),("operation",Turn.Decimal(identity.Operation)),("name",Identifier(name)),("action",operation.Wire())))),identity,cancellation);
        public Task<Intent> LoadAsync(SavedIntent saved, CancellationToken cancellation = default) => Read(V.Obj(("load",saved.Wire())),null,v => ParseSummary(v,saved,Connection,principal,null),cancellation,"loaded");
        public async Task ForgetAsync(Intent intent, CancellationToken cancellation = default) { await Read<object?>(V.Obj(("forget",intent.Id())),null,_ => null,cancellation,"forgotten").ConfigureAwait(false); }
        public Task<Preview> PreviewAsync(Intent intent, CancellationToken cancellation = default) => Read(V.Obj(("preview",intent.Id())),null,v => ParsePreview(v,intent),cancellation,"preview");
        public Task<Reference> StageAsync(Intent intent, CancellationToken cancellation = default) => Read(V.Obj(("stage",intent.Id())),intent.Saved,v => {
            var reference = Reference.Restore(V.Object(v).ToJsonString(CatalogJson)); Owner(reference.Connection,reference.Principal);
            if (reference.Kind != intent.Kind || !JsonNode.DeepEquals(reference.Binding(),intent.Binding()) || reference.Identity.Namespace != intent.Identity.Namespace) throw V.Incompatible("catalog-staged-binding"); return reference;
        },cancellation,"staged");
        public Task<Observation> AdmitAsync(Reference original, CancellationToken cancellation = default) {
            Owner(original.Connection,original.Principal); return Read(V.Obj(("admit",original.Wire())),original,v => ParseObservation(v,original),cancellation,"observation");
        }
        private Task<Observation> Operation(Reference original, string command, ushort steps, CancellationToken cancellation) {
            Owner(original.Connection,original.Principal); if (steps == 0) throw new ArgumentException("Invalid execution budget");
            return Read(V.Obj(("operation",V.Obj(("reference",original.Wire()),("command",command),("steps",(ulong)steps)))),command == "inspect" ? null : original,v => ParseObservation(v,original),cancellation,"observation");
        }
        public Task<Observation> InspectAsync(Reference original, CancellationToken cancellation = default) => Operation(original,"inspect",1,cancellation);
        public Task<Observation> ExecuteAsync(Reference original, ushort steps = 256, CancellationToken cancellation = default) => Operation(original,"execute",steps,cancellation);
        public Task<Observation> CancelAsync(Reference original, CancellationToken cancellation = default) => Operation(original,"cancel",1,cancellation);
        public SnapshotAcquisition PrepareSnapshot(Metadata metadata, ulong operation) {
            var basis = metadata.Basis; Owner(basis.Connection,basis.Principal);
            return SnapshotAcquisition.Restore(V.Obj(("owner",V.Obj(("definition",ContractDefinition),("connection",Connection.Wire(principal)),
                ("object",basis.Interpretation.Interpretation.Object.Wire()),("operation",Turn.Decimal(Positive(operation))))),("expected",metadata.Position.Wire())).ToJsonString(CatalogJson));
        }
        public Task<Snapshot> AcquireSnapshotAsync(SnapshotAcquisition acquisition, CancellationToken cancellation = default) {
            var owner = acquisition.Owner; Owner(owner.Connection,owner.Principal);
            return Read(V.Obj(("retention",V.Obj(("acquire",acquisition.Wire())))),acquisition,v => {
                var snapshot = Snapshot.Restore(V.Object(v).ToJsonString(CatalogJson)); if (!snapshot.Owner.Equals(owner)) throw V.Incompatible("catalog-snapshot-owner"); return snapshot;
            },cancellation,"retention","acquired");
        }
        public Task<SnapshotStatus> SnapshotStatusAsync(SnapshotOwner owner, CancellationToken cancellation = default) {
            Owner(owner.Connection,owner.Principal); return Read(V.Obj(("retention",V.Obj(("status",owner.Wire())))),null,v => ParseSnapshotStatus(v,owner),cancellation,"retention","status");
        }
        public Task<SnapshotMetadata> SnapshotMetadataAsync(Snapshot snapshot, CancellationToken cancellation = default) {
            Owner(snapshot.Owner.Connection,snapshot.Owner.Principal); return Read(V.Obj(("retention",V.Obj(("metadata",snapshot.Wire())))),null,v => ParseSnapshotMetadata(v,snapshot),cancellation,"retention","metadata");
        }
        public Task<Snapshot> ReleaseSnapshotAsync(Snapshot snapshot, CancellationToken cancellation = default) {
            Owner(snapshot.Owner.Connection,snapshot.Owner.Principal);
            return Read(V.Obj(("retention",V.Obj(("release",snapshot.Wire())))),snapshot,v => {
                if (!JsonNode.DeepEquals(v,snapshot.Wire())) throw V.Incompatible("catalog-released-snapshot"); return snapshot;
            },cancellation,"retention","released");
        }
        public async ValueTask DisposeAsync() { try { await worker.CloseAsync().ConfigureAwait(false); } finally { worker.CloseSnapshot(); } }
    }
}
