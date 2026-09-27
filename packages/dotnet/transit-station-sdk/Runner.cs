using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;
using StationBridge = Transit.Station.Sdk.Internal.Bridge;
using StationApi = Transit.Station.Sdk.Internal.NativeApi;

namespace Transit.Station.Sdk;

public sealed class Runner<T> : IDisposable, IAsyncDisposable, IHttpOwner, IGrpcOwner, IDocumentOwner where T : notnull
{
    private sealed class State : IWorkerState<RunnerShutdown>
    {
        private readonly StationBridge bridge;
        private readonly IHandler<T> handler;
        private readonly ICodec<T> codec;
        private readonly FailurePolicy failure;
        private readonly IRecoveryStore? store;
        private readonly StopToken stop;
        private readonly ProcessRef process;
        private FrozenMutation? pending;
        private JsonObject? confirmed;
        private NeedsRecovery? paused;
        private RunnerEvent? lastEvent;
        private bool attempted;
        internal State(ServiceConfig config, IHandler<T> handler, ICodec<T> codec, FailurePolicy failure, Recovery recovery, StopToken stop)
        {
            this.handler = handler; this.codec = codec; this.failure = failure; this.stop = stop; process = config.Activation.Process;
            store = recovery is Recovery.PersistBeforeDispatch persist ? persist.Store : null;
            bridge = StationBridge.Open(config, failure);
            try { NativeValues.Bound(codec, bridge.Limit("message_bytes")); }
            catch { bridge.Dispose(); throw; }
        }
        private RunnerEvent Record(RunnerEvent value) { lastEvent = value; return value; }
        private RunnerEvent Pause(Exception error, string phase, MutationReceipt? receipt = null)
        {
            paused = new NeedsRecovery(pending!, phase, NativeValues.Normalize(error, "recovery-" + phase), receipt);
            return Record(paused);
        }
        private RunnerEvent Accept(JsonObject value)
        {
            confirmed = value;
            MutationReceipt receipt;
            try {
                JsonObject confirmation = Value.Object(value["confirmation"]);
                if (!StationBridge.Matches(confirmation, pending!)) throw Value.Incompatible("confirmation-identity");
                receipt = new MutationReceipt(Value.Number(Value.Object(confirmation["receipt"])["position"], 1));
            } catch (Exception error) { return Pause(error, "confirm"); }
            if (store is not null) {
                try { store.Confirmed(pending!.Identity, receipt); }
                catch (Exception error) { return Pause(error, "confirm", receipt); }
            }
            RunnerEvent result = Value.String(value["event"]) == "blocked" ? new Blocked(pending!.InputPosition, receipt) :
                pending!.Purpose == Purpose.Commit ? new Committed(pending.InputPosition, receipt) : new Progress();
            pending = null; confirmed = null; paused = null; attempted = false;
            return Record(result);
        }
        internal RunnerEvent Attempt()
        {
            if (pending is null) throw new TransitException(ErrorKind.Closed, "no-pending-mutation");
            if (confirmed is not null) return Accept(confirmed);
            if (attempted) {
                try { var known = bridge.Confirmation(pending); if (known is not null) return Accept(known); }
                catch (TransitException error) { return Pause(error, "observe_confirmation"); }
            }
            if (stop.Stopped) return Record(new Stopped());
            if (store is not null) {
                try { store.BeforeDispatch(pending); }
                catch (Exception error) { return Pause(error, "persist"); }
            }
            if (stop.Stopped) return Record(new Stopped());
            attempted = true;
            try { return Accept(bridge.Dispatch()); }
            catch (TransitException error) { return Pause(error, "dispatch"); }
        }
        private bool Handle(JsonObject value)
        {
            Turn turn = new(bridge, value, process, stop);
            TransitException? failure = null;
            try {
                JsonObject input = Value.Object(value["input"]);
                string kind = Value.String(input["kind"]);
                ulong position = Value.Number(input["position"], 1);
                Origin origin = NativeValues.Origin(input["origin"], process.Realm);
                Incoming<T>? message = null; Control? control = null; ResultComplete? result = null;
                switch (kind) {
                    case "cast": case "call": case "reply":
                        T decoded = NativeValues.Decode(codec, Value.Unhex(input["payload"], bridge.Limit("message_bytes")), bridge.Limit("message_bytes"));
                        message = kind switch {
                            "cast" => new Cast<T>(decoded, position, origin),
                            "call" => new Call<T>(decoded, position, origin, NativeValues.Wide(input["correlation"], true)),
                            _ => new Reply<T>(decoded, position, origin, NativeValues.Wide(input["correlation"], true))
                        };
                        break;
                    case "cancel": case "timeout":
                        control = new Control(kind == "cancel" ? ControlKind.Cancel : ControlKind.Timeout, position, origin, NativeValues.Wide(input["correlation"], true)); break;
                    case "result_complete":
                        result = new ResultComplete(position, origin, NativeValues.Wide(input["correlation"], true)); break;
                    default: throw new TransitException(ErrorKind.Handler, "unsupported-input");
                }
                // Decode before initialization can stage any private mutation.
                if (Value.Boolean(value["initializing"]) && !stop.Stopped) handler.Initialize(turn);
                if (!stop.Stopped) {
                    if (control is not null) handler.OnControl(turn, control);
                    else if (result is not null) handler.OnResult(turn, result);
                    else handler.OnMessage(turn, message!);
                }
            } catch (Exception error) { failure = NativeValues.Normalize(error, "handler"); }
            finally { turn.EndScope(); }
            if (stop.Stopped) { bridge.Discard(turn.Scope); return false; }
            if (turn.Poison is not null) {
                try { bridge.Discard(turn.Scope); } catch (TransitException) { }
                throw turn.Poison;
            }
            try { bridge.Finish(turn.Scope, failure is not null); }
            catch (TransitException error) when (failure is not null && this.failure == FailurePolicy.Stop && error.Code == "ForeignHandlerFailure") { throw failure; }
            return true;
        }
        internal RunnerEvent Next()
        {
            if (paused is not null) return paused;
            if (stop.Stopped) return Record(new Stopped());
            if (pending is not null) return Attempt();
            for (int count = 0; count < 16; count++) {
                if (stop.Stopped) return Record(new Stopped());
                JsonObject value = bridge.Prepare();
                switch (Value.String(value["event"])) {
                    case "pending": pending = bridge.Pending(value); return Attempt();
                    case "idle": return Record(new Idle());
                    case "blocked": return Record(new Blocked(null, null));
                    case "ready": if (!Handle(value)) return Record(new Stopped()); break;
                    case "progress": break;
                    default: throw Value.Incompatible("native-event");
                }
            }
            return Record(new Progress());
        }
        public RunnerShutdown Evidence() => new(pending, lastEvent);
        internal R ReplayAccess<R>(Func<StationBridge, R> action)
        {
            if (pending is not null) throw new TransitException(ErrorKind.Busy, "pending-mutation");
            return action(bridge);
        }
        internal Http.Reader OpenHttp(IHttpOwner owner, Http.Outcome outcome, Http.ReplayPolicy policy)
        {
            if (outcome.Phase != Http.Phase.Observed || outcome.Reference is null || outcome.Resource.Realm != process.Realm)
                throw new ArgumentException("Expected an observed outcome in this realm");
            JsonObject value = ReplayAccess(bridge => bridge.HttpRead(Value.Obj(("open", Value.Obj(("reference", Http.Hex(outcome.Reference)),
                ("policy", policy == Http.ReplayPolicy.Captured ? "captured" : "require_unredacted"))))));
            return new Http.Reader(owner, Value.Number(value["opened"], 1));
        }
        internal Grpc.Reader OpenGrpc(IGrpcOwner owner, Grpc.Outcome outcome, Grpc.ReplayPolicy policy)
        {
            if (outcome.Phase != Grpc.Phase.Observed || outcome.Reference is null || outcome.Resource.Realm != process.Realm)
                throw new ArgumentException("Expected an observed outcome in this realm");
            JsonObject value = ReplayAccess(bridge => bridge.GrpcRead(Value.Obj(("open", Value.Obj(("reference", Grpc.Hex(outcome.Reference)),
                ("policy", policy == Grpc.ReplayPolicy.Captured ? "captured" : "require_unredacted"))))));
            return new Grpc.Reader(owner, Value.Number(value["opened"], 1));
        }
        public void Dispose() => bridge.Dispose();
    }
    private readonly Worker<State, RunnerShutdown> worker;
    public StopToken StopToken { get; }
    private readonly ulong realm;
    private Runner(Worker<State, RunnerShutdown> worker, StopToken stop, ulong realm) { this.worker = worker; StopToken = stop; this.realm = realm; }
    public static async Task<Runner<T>> OpenAsync(ServiceConfig config, IHandler<T> handler, ICodec<T> codec, FailurePolicy failure, Recovery recovery)
    {
        ArgumentNullException.ThrowIfNull(config); ArgumentNullException.ThrowIfNull(handler); ArgumentNullException.ThrowIfNull(codec); ArgumentNullException.ThrowIfNull(recovery);
        NativeValues.SynchronousCallbacks(handler, typeof(IHandler<T>));
        if (recovery is Recovery.PersistBeforeDispatch persist) NativeValues.SynchronousCallbacks(persist.Store, typeof(IRecoveryStore));
        StopToken stop = new();
        var worker = await Worker<State, RunnerShutdown>.OpenAsync(() => new State(config, handler, codec, failure, recovery, stop), StationApi.MinimumStackBytes).ConfigureAwait(false);
        return new Runner<T>(worker, stop, config.Activation.Process.Realm);
    }
    public Task<RunnerEvent> NextAsync(CancellationToken cancellation = default) => worker.Invoke(state => state.Next(), cancellation);
    public Task<RunnerEvent> ReconcileAsync(CancellationToken cancellation = default) => worker.Invoke(state => state.Attempt(), cancellation);
    public Task<RunnerShutdown> EvidenceAsync(CancellationToken cancellation = default) => worker.Invoke(state => state.Evidence(), cancellation);
    public Document.Reader Documents => new(this, realm);
    Task<R> IDocumentOwner.DocumentAccess<R>(Func<StationBridge, R> action, CancellationToken cancellation) => worker.Invoke(state => state.ReplayAccess(action), cancellation);
    Task<R> IHttpOwner.HttpAccess<R>(Func<StationBridge, R> action, CancellationToken cancellation) => worker.Invoke(state => state.ReplayAccess(action), cancellation);
    void IHttpOwner.CheckClose() => worker.CheckClose();
    public Task<Http.Reader> OpenHttpAsync(Http.Outcome outcome, Http.ReplayPolicy policy = Http.ReplayPolicy.Captured, CancellationToken cancellation = default)
    {
        ArgumentNullException.ThrowIfNull(outcome);
        if (policy is not (Http.ReplayPolicy.Captured or Http.ReplayPolicy.RequireUnredacted)) throw new ArgumentException("Invalid replay policy");
        return worker.Invoke(state => state.OpenHttp(this, outcome, policy), cancellation);
    }
    Task<R> IGrpcOwner.GrpcAccess<R>(Func<StationBridge, R> action, CancellationToken cancellation) => worker.Invoke(state => state.ReplayAccess(action), cancellation);
    void IGrpcOwner.CheckClose() => worker.CheckClose();
    public Task<Grpc.Reader> OpenGrpcAsync(Grpc.Outcome outcome, Grpc.ReplayPolicy policy = Grpc.ReplayPolicy.Captured, CancellationToken cancellation = default)
    {
        ArgumentNullException.ThrowIfNull(outcome);
        if (policy is not (Grpc.ReplayPolicy.Captured or Grpc.ReplayPolicy.RequireUnredacted)) throw new ArgumentException("Invalid replay policy");
        return worker.Invoke(state => state.OpenGrpc(this, outcome, policy), cancellation);
    }
    public void Stop() => StopToken.Stop();
    public Task<RunnerShutdown> CloseAsync() { worker.CheckClose(); Stop(); return worker.CloseAsync(); }
    public RunnerShutdown CloseSnapshot() { worker.CheckClose(); Stop(); return worker.CloseSnapshot(); }
    public RunnerShutdown? RetainedEvidence => worker.RetainedEvidence;
    public void Dispose() { CloseSnapshot(); }
    public async ValueTask DisposeAsync() { await CloseAsync().ConfigureAwait(false); }
}
