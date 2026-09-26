using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using RawBridge = Transit.Client.Internal.Bridge;

namespace Transit.Station.Sdk.Internal;

internal sealed class Bridge : IWorkerState<object?>
{
    private static readonly JsonObject Schemas = Value.Object(Value.ReadContract(typeof(Bridge).Assembly, "transit.station.contract.json")["schemas"]);
    private readonly NativePackage package;
    internal readonly NativeApi Api;
    internal readonly JsonObject Caps;
    private RawBridge? raw;
    private IntPtr server;
    internal Bridge(string? nativeDirectory)
    {
        if (typeof(Transit.Client.Client).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion != "0.2.0") throw Value.Incompatible("client-sdk-version");
        package = new NativePackage("station", nativeDirectory);
        try {
            Api = new NativeApi(package.Library);
            if (Api.station_abi_version() != NativeApi.Version) throw Value.Incompatible("station-version");
            uint status = Api.station_growing_capabilities(out var buffer);
            Caps = Result(status, buffer, "native-capabilities", schema: "GrowingCapabilities");
            if (Value.Number(Caps["version"], 1) != 1 || Value.String(Caps["profile"]) != "growing_v3") throw Value.Incompatible("station-profile");
            foreach (string name in new[] { "gated_dispatch", "retained_confirmation", "scoped_turns", "paged_state", "tables", "retained_sources" }) {
                if (!Value.Boolean(Caps[name])) throw new TransitException(ErrorKind.UnsupportedCapability, "native-capabilities");
            }
        } catch (Exception error) {
            package.Dispose();
            if (error is EntryPointNotFoundException or MarshalDirectiveException) throw Value.Incompatible("native-exports");
            throw;
        }
    }
    internal static Bridge Open(ServiceConfig config, FailurePolicy failure)
    {
        if (failure is not (FailurePolicy.Stop or FailurePolicy.BlockInput)) throw new ArgumentException("Select a handler failure policy");
        Bridge bridge = new(config.Client.NativeDirectory);
        try {
            if (config.QueryResults && !Value.Boolean(bridge.Caps["query_results"])) throw new TransitException(ErrorKind.UnsupportedCapability, "query-results");
            bridge.raw = new RawBridge(config.Client);
            var authority = bridge.raw.Capabilities(config.Activation.Credential);
            if (!authority.AssociationLookup || !authority.ScopedRetry || !authority.RetainedVersions) throw new TransitException(ErrorKind.UnsupportedCapability, "authority-capabilities");
            var activation = config.Activation;
            byte[] endpoint = Value.Utf8.GetBytes(config.Client.Endpoint.ToString());
            byte[] document = Value.Json(Value.Obj(("profile", "growing_v3"), ("realm", activation.Process.Realm), ("principal", activation.Credential.Principal),
                ("pid", activation.Process.Pid), ("generation", activation.Generation), ("association", config.Association), ("timeout_ms", config.Client.TimeoutMillis),
                ("failure_policy", failure == FailurePolicy.Stop ? "stop" : "block_input"), ("query_results", config.QueryResults)));
            byte[] seed = RawBridge.Seed(activation.Credential.SeedFile);
            try {
                uint status = bridge.Api.station_growing_create(NativeApi.Version, endpoint, (nuint)endpoint.Length, seed, document, (nuint)document.Length, out bridge.server);
                if (status != 0) throw Value.NativeError(status, null, "runner-create");
                if (bridge.server == IntPtr.Zero) throw Value.Incompatible("runner-create");
            } finally { CryptographicOperations.ZeroMemory(seed); }
            return bridge;
        } catch (Exception) { bridge.Dispose(); throw; }
    }
    internal int Limit(string name) => checked((int)Value.Number(Caps[name], 1));
    internal byte[] Buffer(uint status, IntPtr pointer, string phase)
    {
        byte[] bytes;
        try {
            nuint size = pointer == IntPtr.Zero ? 0 : Api.station_buffer_size(pointer);
            if (size > (nuint)Value.MaxLine) throw Value.Incompatible("native-buffer-bound");
            bytes = new byte[(int)size];
            if (size > 0) Marshal.Copy(Api.station_buffer_data(pointer), bytes, 0, bytes.Length);
        } finally { Api.station_buffer_destroy(pointer); }
        if (status != 0) {
            JsonNode? detail = null;
            if (bytes.Length != 0) { try { detail = Value.Parse(bytes); } catch (TransitException) { } }
            throw Value.NativeError(status, detail, phase);
        }
        return bytes;
    }
    private JsonObject Result(uint status, IntPtr pointer, string phase, bool mutation = false, string? schema = null)
    {
        try {
            JsonObject value = Value.Object(Value.Parse(Buffer(status, pointer, phase)));
            if (schema is not null) Schema.Require(Value.Object(Schemas[schema]), value);
            return value;
        }
        catch (TransitException error) when (mutation && !error.Rejected && error.Kind != ErrorKind.UnknownOutcome) {
            throw new TransitException(ErrorKind.UnknownOutcome, "receipt", 6);
        } catch (Exception error) when (mutation && error is not TransitException) { throw new TransitException(ErrorKind.UnknownOutcome, "receipt", 6); }
    }
    internal JsonObject Prepare()
    {
        ulong deadline = checked((ulong)DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() + 30000);
        uint status = Api.station_growing_prepare(server, deadline, out var buffer);
        return Result(status, buffer, "prepare-turn", schema: "GrowingEvent");
    }
    internal JsonObject Apply(ulong scope, JsonObject action)
    {
        byte[] bytes = Value.Json(action);
        if (bytes.Length > Value.MaxBody) throw new ArgumentException("Action exceeds its bound");
        uint status = Api.station_growing_apply(server, scope, bytes, (nuint)bytes.Length, out var buffer);
        return Result(status, buffer, "apply", schema: "GrowingResult");
    }
    internal void Finish(ulong scope, bool failed)
    {
        uint status = Api.station_growing_finish_result(server, scope, failed ? 1u : 0u, out var buffer);
        Buffer(status, buffer, "finish");
    }
    internal void Discard(ulong scope)
    {
        uint status = Api.station_growing_discard(server, scope);
        if (status != 0) throw Value.NativeError(status, null, "discard");
    }
    internal JsonObject Dispatch()
    {
        uint status = Api.station_growing_dispatch(server, out var buffer);
        return Result(status, buffer, "dispatch", true, "GrowingEvent");
    }
    internal FrozenMutation Pending(JsonObject value)
    {
        Purpose purpose = Value.String(value["pending_kind"]) switch { "permit" => Purpose.Permit, "open" => Purpose.Open, "commit" => Purpose.Commit, _ => throw Value.Incompatible("pending-purpose") };
        uint status = Api.station_growing_pending(server, out var buffer);
        byte[] bytes = Buffer(status, buffer, "pending");
        using var pending = raw!.RecoverMutation(bytes);
        bool matches = purpose switch { Purpose.Permit => pending.Info.Command == "begin_turn", Purpose.Open => pending.Info.Command == "open_view", _ => pending.Info.Command is "turn" or "turn_with_versions" };
        if (!matches) throw Value.Incompatible("pending-command");
        return new(pending.Info.Identity, purpose, Value.Number(value["pending_input"], 1), new Bytes(bytes));
    }
    internal static bool Matches(JsonObject value, FrozenMutation pending) => Value.String(value["kind"]) == pending.Purpose.ToString().ToLowerInvariant() && Value.Number(value["input"], 1) == pending.InputPosition;
    internal JsonObject? Confirmation(FrozenMutation pending)
    {
        try {
            uint status = Api.station_growing_confirmation(server, out var buffer);
            JsonObject result = Result(status, buffer, "observe-confirmation", schema: "GrowingEvent");
            return result["confirmation"] is JsonObject value && Matches(value, pending) ? result : null;
        } catch (TransitException error) when (error.Kind == ErrorKind.TurnExpired) { return null; }
    }
    public object? Evidence() => null;
    public void Dispose()
    {
        try { if (server != IntPtr.Zero) { Api.station_growing_destroy(server); server = IntPtr.Zero; } }
        finally { try { raw?.Dispose(); } finally { package.Dispose(); } }
    }
}
